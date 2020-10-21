# mVotes

| Action Status | Discord |
|:-------------:|:-------:|
| [![Action Status](https://github.com/Bara/mVotes/workflows/Compile%20with%20SourceMod/badge.svg)](https://github.com/Bara/mVotes/actions) | [![Discord](https://img.shields.io/discord/388685157286019072.svg)](https://discord.gg/NUMQfgs) |

This plugin is a standalone polls plugin. Admins with the vote flag can create, extend and close polls with a pretty easy to use menu. It's also possible to give multiple votes on one poll. All data and results are saved in a mysql database. Active polls, options and votes are cached as enum struct in a arraylist to increase the performance without many mysql queries.

## Which features will not added (except anyone do it)
 - Change of title/options
   - I want try to prevent that on the legal way, otherwise it would fake the results
 - Renewal of expired polls
   - Expired or closed polls are done and shouldn't be reopened

## ToDo
 - Currently nothing, open an issue if you've a idea

## Known issues
 - Nothing yet, open an issue if you found something
