# brobbot-slack

This is a [Brobbot](https://npmjs.org/package/brobbot) adapter to use with [Slack](https://slack.com).  

## Getting Started

#### Adding Slack adapter

In your [brobbot-instance](https://github.com/b3nj4m/brobbot-instance):

```bash
npm install brobbot-slack --save
```

Check out the [brobbot docs](https://github.com/b3nj4m/hubot/tree/master/docs/README.md) for further guidance on how to build your bot

#### Testing your bot instance locally

- `BROBBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd ./index.sh -a slack`

#### Deploying to Heroku

You can use the Heroku deploy button on the [brobbot-slack-instance](https://github.com/b3nj4m/brobbot-slack-instance) project, or you can do it manually:

This is a modified set of instructions based on the [instructions on the Brobbot wiki](https://github.com/b3nj4m/hubot/blob/master/docs/deploying/heroku.md).

- Make sure `brobbot-slack` is in your `package.json` dependencies in your [brobbot-instance](https://github.com/b3nj4m/brobbot-instance).
- Edit your `Procfile` and change it to use the `slack` adapter:

        web: ./index.sh -a slack

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- `heroku create my-company-slackbot`
- Activate the Hubot service on your ["Team Services"](http://my.slack.com/services/new/hubot) page inside Slack.
- Add the [config variables](#configuration). For example:

        % heroku config:add HEROKU_URL=http://soothing-mists-4567.herokuapp.com
        % heroku config:add BROBBOT_SLACK_TOKEN=dqqQP9xlWXAq5ybyqKAU0axG

- Deploy and start the bot:

        % git push heroku master
        % heroku ps:scale web=1

- Profit!

## Upgrading from earlier versions of Hubot

Version 4 of the brobbot-slack adapter requires different server support to
previous versions. If you have an existing "hubot" integration set up you'll
need to upgrade:

- Go to https://my.slack.com/services/new/hubot and create a new hubot
  integration
- Run `npm install brobbot-slack@latest --save`
  to update your code.
- Test your bot instance locally using:
  `BROBBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd ./index.sh -a slack`
- Update your production startup scripts to pass the new `BROBBOT_SLACK_TOKEN`.
  You can remove the other `BROBBOT_SLACK_*` environment variables if you want.
- Deploy your new brobbot to production.
- Once you're happy it works, remove the old hubot integration from
  https://my.slack.com/services

## Configuration

This adapter uses the following environment variables:

 - `BROBBOT_SLACK_TOKEN` - This is the API token for the Slack user you would like to run Hubot under.

To add or remove your bot from specific channels or private groups, you can use the /kick and /invite slash commands that are built into Slack.

## Copyright

Copyright &copy; Slack Technologies, Inc. MIT License; see LICENSE for further details.
