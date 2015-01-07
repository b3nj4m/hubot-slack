# brobbot-slack

This is a [Brobbot](http://b3nj4m.github.io/hubot) adapter to use with [Slack](https://slack.com).  

## Getting Started

#### Adding Slack adapter

- `npm install brobbot-slack --save`
- Initialize git and make your initial commit
- Check out the [brobbot docs](https://github.com/b3nj4m/hubot/tree/master/README.md) for further guidance on how to build your bot

#### Testing your bot locally

- `./bin/brobbot`

#### Deploying to Heroku

This is a modified set of instructions based on the [instructions on the Brobbot wiki](https://github.com/b3nj4m/hubot/blob/master/docs/deploying/heroku.md).

- Make sure `brobbot-slack` is in your `package.json` dependencies
- Edit your `Procfile` and change it to use the `slack` adapter:

        web: bin/brobbot --adapter slack

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- `heroku create my-company-slackbot`
- `heroku addons:add redistogo:nano`
- Activate the Hubot service on your ["Team Services"](http://my.slack.com/services/new/hubot) page inside Slack.
- Add the [config variables](#adapter-configuration). For example:

        % heroku config:add HEROKU_URL=http://soothing-mists-4567.herokuapp.com
        % heroku config:add BROBBOT_SLACK_TOKEN=dqqQP9xlWXAq5ybyqKAU0axG
        % heroku config:add BROBBOT_SLACK_TEAM=myteam
        % heroku config:add BROBBOT_SLACK_BOTNAME=slack-brobbot

- Deploy and start the bot:

        % git push heroku master
        % heroku ps:scale web=1

- Profit!

## Adapter configuration

This adapter uses the following environment variables:

#### BROBBOT\_SLACK\_TOKEN

This is the service token you are given when you add Brobbot to your Team Services.

#### BROBBOT\_SLACK\_TEAM

This is your team's Slack subdomain. For example, if your team is `https://myteam.slack.com/`, you would enter `myteam` here.

#### BROBBOT\_SLACK\_BOTNAME

Optional. What your Brobbot is called on Slack. If you entered `slack-brobbot` here, you would address your bot like `slack-brobbot: help`. Otherwise, defaults to `slackbot`.

#### BROBBOT\_SLACK\_CHANNELMODE

Optional. If you entered `blacklist`, Brobbot will not post in the rooms specified by BROBBOT_SLACK_CHANNELS, or alternately *only* in those rooms if `whitelist` is specified instead. Defaults to `blacklist`.

#### BROBBOT\_SLACK\_CHANNELS

Optional. A comma-separated list of channels to either be blacklisted or whitelisted, depending on the value of BROBBOT_SLACK_CHANNELMODE.

#### BROBBOT\_SLACK\_LINK\_NAMES

Optional. By default, Slack will not linkify channel names (starting with a '#') and usernames (starting with an '@'). You can enable this behavior by setting BROBBOT_SLACK_LINK_NAMES to 1. Otherwise, defaults to 0. See [Slack API : Message Formatting Docs](https://api.slack.com/docs/formatting) for more information.

## Under the Hood

#### Receiving Messages:

The slack adapter adds a path to the robot's router that will accept POST requests to:

`/hubot/slack-webhook`

Expected parameters:

- text
- user_id
- user_name
- channel_id
- channel_name

If there is a message and it can deduce an author from those paramters, it'll create a new [TextMessage](https://github.com/b3nj4m/hubot-slack/blob/master/src/slack.coffee#L171-L173) object and have the robot receive it, from there proceeding down the regular brobbot path.

#### Sending Messages

When a script calls `send()` or `reply()` this adapter makes a POST request to your team's specific URL webhook:

`https://<your_team_name>.slack.com/services/hooks/hubot`

with a JSON-formatted body including the following dictionary:

- username
- channel
- text
- link_names (optionally)

#### Message to a specific room:

Sometime, it's useful to send a message regardless of the channel's activity (like `robot.hear` or `robot.response`). Brobbot has `robot.messageRoom` available for this use case.

Slack API uses channel ID's by default, which uses computer-friendly alphanumeric ID. To use the pretty names, prefix it with a hash.

```coffeescript
robot.respond /hello$/i, (msg) ->
  robot.messageRoom '#general', 'hello there'
```
