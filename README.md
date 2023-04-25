# Hardcore (EZ Edition)

![Logo](https://github.com/randyrandomrnd/WoW_Hardcore/blob/master/logo.png?raw=true)

Modified EZ Edition addon that basically allows you to break most hardcore rules, while still getting the achievement, and becoming verified by the mods. This is not a recommended way to play hardcore, but it's a way to play hardcore without having to worry about the ruleset.

I made this as a proof of concept after experiencing data corruption on my main character, and losing my verified run. I wanted to see if it was possible to spoof the hardcore addon, and it was. I'm not going to use this addon to play hardcore, but I'm releasing it for those who want to play hardcore without having to worry about the ruleset.

Where there is possibility of cheats, there will be cheating. Now most people won't want to cheat themselves, but knowing there are people in the world who have died several times, cheated their achievements, and still have their runs verified, makes it a lot less interesting to play for me. I'm not going to play hardcore anymore, but I'm releasing this addon for those who want to play hardcore without having to worry about the ruleset.

On a general level, there is basically no way to prevent cheating in an addon like this. Every communication relies on what the client sends, which can easily be spoofed. The only way to prevent cheating is to have the server verify everything, and this is not possible with the current API.

## Changes from original Hardcore

- Allows most ruleset actions that are blocked by the regular addon, including deaths
- Mailbox and Auction House access
- No death reports
- No achievement fails
- No restrictions on trading
- Allows bubble hearthing
- Always makes a verify string, i.e. no FAIL (Contact Mod) messages

## What it doesn't do

- The main hardcore addon tracks playtime and broadcasts this to guild and the server addon channel. Making a completely verified EZ run with all timings correct is tricky and requires a lot of effort.
- Dungeon spam is still blocked, this is an easy fix for the future. It's also possible to have features where you can complete previously failed runs and still get the achievement, but this is not implemented yet.
- Even though individual achievements will complete, they have not been made so that thgey don't warn or spam you. But rest assured that they won't fail, and you will get credit. It's an easy fix for the future.

## How does it do it

- It highjacks a bunch of checks that the game does when you do certain actions, and allows them to go through. This is done by replacing the original functions with new ones that do the same thing, but also allow the action to go through.
- The achievement will still show as failing sometimes, but won't actually fail (and play the fail sound). For example doing the sword and board warrior challenge will spam the chat with errors, if you're wearing lets say a 2h, but nothing will happen. The achievement will still complete.

## Problems

- WoW is an MMO. If people see something out of place, see you dying, see you wearing items or doing things that don't correspond to achievement requirements, they will report you. This is not a problem with the addon, but with the game itself.
- Stay lowkey, don't do every achievement under the sun, and don't die within range of others.

## WoW Official Hardcore

- The reason this is so easily possible to spoof is the fact that the addon developers are limited to functionality that is provided through the WoW API. The API is not designed to be used for hardcore verification, and as such it is very easy to spoof. The addon developers have no way of knowing if you're actually doing the things you broadcast or not, and as such they can't prevent you from spoofing it. This is not a problem with the addon, but with the game itself. There is a lot of work required to make a hardcore mode that is actually hardcore, and it's not something that can be done by a few addon developers, it requires a lot of work from the game developers themselves.
- There are hundreds of problems with doing official hardcore that I won't elaborate here. For example the addon has special checks in place for a quest that makes you drink the Videre Elixir and kills you. The game is basically made to kill you at some points. Now for a huge playerbase with the recent rice in hardcore popularity, these special events will totally destroy your run depending on how Blizzard will implement hardcore. Will Blizzard allow appeals, will they rework certain parts of the game to work in a hardcore setting? Anything they don't do, will be easily manipulated by rogue addons like this one. For a big company like Blizzard who needs to cater to customers, how can they make something that is both fair, enjoyable, without a huge rework of the basic game. Just counting deaths in the backend and letting mods handle the rest is not enough, imho.

## Bugs

- This has not been tested almost at all, because I have lost all interest and faith in hardcore after doing this little project.
- Grouping might be slightly broken.
- There is no config tab where you can pick whatever checks you want to disable, but they can be edited in the main Hardcore.lua file, with boolean feature flags at the top of teh file. The addon already comes with some defaults that basically allow you to break most ruleset actions, while still getting the achievement, and becoming verified by the mods.

## Now what?

I did this is a quick proof of concept. This could be made however complex you'd want. If you're interested in paying for software development services, contact me. If the addon creators would like to chat I am open to that as well, but there is barely anything that can be done to fix the root causes without Blizzard intervening and adding hardcore checks and code to their server code.

# Original README

## What does this addon do?

- (Death Reports) Shows in-game and in guild chat when someone dies
- (HC Verification) Logs play time and tracks deaths for [Hardcore Community Leaderboards and Hall of Legends](https://classichc.net/)
- (Accountability) Shows an overview of everyone in guild running Hardcore addon
- (Grief Protection) Warns you as you target a friendly/enemy that is Pvp flagged
- (Hardcore Rules) Prevents Mailbox and Auction House Access
- (Bubble Hearth) Warns the player while Bubble hearthing. Also reports to guild

## FAQ

### Addon says active time is much lower than played time

The addon tracks a certain percentage of your addon uptime compared to total /played. If it is about seconds or minutes - no problem. If it is about hours - consider rerolling before level 20. After level 20, record the run as instructed by the error message.

this can happen due to:

- Disconnect or Game crash. This happens due to WoW's WTF folder not updating due to the unexpected end of the game process.
- the Game is killed with alt+f4 or otherwise WITHOUT logging out first (exit game IS NOT THE SAME as logout)
- the character has been played on two or more computers. Refer to the Multi-pc workaround below

### The addon is missing recorded levels after a DC / Crash

This happens due to WoW's WTF folder not updating due to the unexpected end of the game process. If you happen to have crashes every now and then consider typing /reload every 15min or so when safely out of combat's harm. It will save the process for the addon.

### I checked the accountability tab and there are people A LOT of in red, what do I do?

Close the addon tab and open it again after a minute or so. They should be green now. It takes time to sync at times.

### How can I see how much has been recorded on my character?

```
/dump Hardcore_Character.time_tracked..', '..Hardcore_Character.time_played..', '..Hardcore_Character.tracked_played_percentage
```

## WARNING - MULTIPLE PCs SUPPORT - WARNING!!!!!

This addon DOES NOT support one character across multiple PCs! The consequence of this is potentially losing a VERIFIED run!

Below are steps for a work-around.

### Syncing the Saved Variable file

Not recommended if below steps are confusing

If you want to play on multiple PCs, you CAN sync the following file to Google Drive / Dropbox before and after play sessions.

```
{WOW_INSTALL_DIRECTORY}\_classic_era\WTF\Account\{ACCOUNT_ID or ACCOUNT_NAME}\{SERVER_NAME}\{CHARACTER_NAME}\SavedVariables\Hardcore.lua
```

#### After Playing on PC #1

1. Logout and exit game properly
2. Copy above file on PC #1 to Cloud / storage

#### Before Playing on PC #2

1. If above folder path doesn't exist yet on PC #2, log in on the character and logout immediately. WoW will create the folder for you
2. Your game MUST be OFF for the below steps
3. Copy file from Cloud / storage to above location on PC #2
4. Overwrite file on PC #2
5. Start Playing
