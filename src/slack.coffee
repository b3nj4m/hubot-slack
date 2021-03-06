{Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage} = require 'brobbot'
{SlackTextMessage, SlackRawMessage, SlackBotMessage} = require './message'
{SlackRawListener, SlackBotListener} = require './listener'

SlackClient = require 'slack-client'
Util = require 'util'
Q = require 'q'

class SlackBot extends Adapter
  @MAX_MESSAGE_LENGTH: 4000
  @MIN_MESSAGE_LENGTH: 1

  constructor: (robot) ->
    @robot = robot
    @readyDefer = Q.defer()
    @ready = @readyDefer.promise

  run: ->
    # Take our options from the environment, and set otherwise suitable defaults
    options =
      token: process.env.BROBBOT_SLACK_TOKEN
      autoReconnect: true
      autoMark: true

    return @robot.logger.error "No services token provided to Brobbot" unless options.token
    return @robot.logger.error "v2 services token provided, please follow the upgrade instructions" unless (options.token.substring(0, 5) == 'xoxb-')

    @options = options

    # Create our slack client object
    @client = new SlackClient options.token, options.autoReconnect, options.autoMark

    # Setup event handlers
    @client.on 'error', @.error
    @client.on 'loggedIn', @.loggedIn
    @client.on 'open', @.open
    @client.on 'close', @.clientClose
    @client.on 'message', @.message
    @client.on 'userChange', @.userChange

    # Start logging in
    @client.login()

  error: (error) =>
    @robot.logger.error "Received error #{JSON.stringify error}"
    @robot.logger.error error.stack
    @robot.logger.error "Exiting in 1 second"
    setTimeout process.exit.bind(process, 1), 1000

  loggedIn: (self, team) =>
    @robot.logger.info "Logged in as #{self.name} of #{team.name}, but not yet connected"

    # store a copy of our own user data
    @self = self

    # Provide our name to Brobbot
    @robot.name = self.name

    for id, user of @client.users
      @userChange user

  userChange: (user) =>
    newUser = {id: user.id, name: user.name, real_name: user.real_name, email_address: user.profile.email}

    @robot.brain.addUser(newUser).then =>
      @robot.brain.userForId user.id

  open: =>
    @robot.logger.info 'Slack client now connected'

    # Tell Brobbot we're connected so it can load scripts
    @readyDefer.resolve()

  clientClose: =>
    @robot.logger.info 'Slack client closed'
    @client.removeListener 'error', @.error
    @client.removeListener 'loggedIn', @.loggedIn
    @client.removeListener 'open', @.open
    @client.removeListener 'close', @.clientClose
    @client.removeListener 'message', @.message
    process.exit 0

  message: (msg) =>
    # Ignore our own messages
    return if msg.user == @self.id

    channel = @client.getChannelGroupOrDMByID msg.channel if msg.channel

    if msg.hidden or (not msg.text and not msg.attachments) or msg.subtype is 'bot_message' or not msg.user or not channel
      # use a raw message, so scripts that care can still see these things

      if msg.user
        getUser = @robot.brain.userForId msg.user
      else
        # We need to fake a user because, at the very least, CatchAllMessage
        # expects it to be there.
        user = {}
        user.name = msg.username if msg.username?
        getUser = Q user

      getUser.then (user) =>
        user.room = channel.name if channel

        rawText = msg.getBody()
        text = @removeFormatting rawText

        if msg.subtype is 'bot_message'
          @robot.logger.debug "Received bot message: '#{text}' in channel: #{channel?.name}, from: #{user?.name}"
          @receive new SlackBotMessage user, text, rawText, msg
        else
          @robot.logger.debug "Received raw message (subtype: #{msg.subtype})"
          @receive new SlackRawMessage user, text, rawText, msg

    else
      # Process the user into a full brobbot user
      @robot.brain.userForId(msg.user).then (user) =>
        user.room = channel.name

        # Test for enter/leave messages
        if msg.subtype is 'channel_join' or msg.subtype is 'group_join'
          @robot.logger.debug "#{user.name} has joined #{channel.name}"
          @receive new EnterMessage user

        else if msg.subtype is 'channel_leave' or msg.subtype is 'group_leave'
          @robot.logger.debug "#{user.name} has left #{channel.name}"
          @receive new LeaveMessage user

        else if msg.subtype is 'channel_topic' or msg.subtype is 'group_topic'
          @robot.logger.debug "#{user.name} set the topic in #{channel.name} to #{msg.topic}"
          @receive new TopicMessage user, msg.topic, msg.ts

        else
          # Build message text to respond to, including all attachments
          rawText = msg.getBody()
          text = @removeFormatting rawText

          @robot.logger.debug "Received message: '#{text}' in channel: #{channel.name}, from: #{user.name}"

          # If this is a DM, pretend it was addressed to us
          if msg.getChannelType() == 'DM'
            text = "#{@robot.name} #{text}"

          @receive new SlackTextMessage user, text, rawText, msg

  removeFormatting: (text) ->
    # https://api.slack.com/docs/formatting
    text = text.replace ///
      <              # opening angle bracket
      ([@#!])?       # link type
      ([^>|]+)       # link
      (?:\|          # start of |label (optional)
        ([^>]+)      # label
      )?             # end of label
      >              # closing angle bracket
    ///g, (m, type, link, label) =>

      switch type

        when '@'
          if label then return label
          user = @client.getUserByID link
          if user
            return "@#{user.name}"

        when '#'
          if label then return label
          channel = @client.getChannelByID link
          if channel
            return "\##{channel.name}"

        when '!'
          if link in ['channel','group','everyone']
            return "@#{link}"

        else
          link = link.replace /^mailto:/, ''
          if label and -1 == link.indexOf label
            "#{label} (#{link})"
          else
            link
    text = text.replace /&lt;/g, '<'
    text = text.replace /&gt;/g, '>'
    text = text.replace /&amp;/g, '&'
    text

  send: (envelope, messages...) ->
    channel = @client.getChannelGroupOrDMByName envelope.room

    for msg in messages
      continue if msg.length < SlackBot.MIN_MESSAGE_LENGTH

      @robot.logger.debug "Sending to #{envelope.room}: #{msg}"

      if msg.length <= SlackBot.MAX_MESSAGE_LENGTH
        channel.send msg

      # If message is greater than MAX_MESSAGE_LENGTH, split it into multiple messages
      else
        submessages = []

        while msg.length > 0
          if msg.length <= SlackBot.MAX_MESSAGE_LENGTH
            submessages.push msg
            msg = ''

          else
            # Split message at last line break, if it exists
            maxSizeChunk = msg.substring(0, SlackBot.MAX_MESSAGE_LENGTH)

            lastLineBreak = maxSizeChunk.lastIndexOf('\n')
            lastWordBreak = maxSizeChunk.match(/\W\w+$/)?.index

            breakIndex = if lastLineBreak > -1
              lastLineBreak
            else if lastWordBreak
              lastWordBreak
            else
              SlackBot.MAX_MESSAGE_LENGTH

            submessages.push msg.substring(0, breakIndex)

            # Skip char if split on line or word break
            breakIndex++ if breakIndex isnt SlackBot.MAX_MESSAGE_LENGTH

            msg = msg.substring(breakIndex, msg.length)

        channel.send m for m in submessages

  reply: (envelope, messages...) ->
    @robot.logger.debug "Sending reply"

    for msg in messages
      # TODO: Don't prefix username if replying in DM
      @send envelope, "#{envelope.user.name}: #{msg}"

  topic: (envelope, strings...) ->
    channel = @client.getChannelGroupOrDMByName envelope.room
    channel.setTopic strings.join "\n"

module.exports = SlackBot
