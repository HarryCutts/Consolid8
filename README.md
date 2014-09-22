Consolid8
=========

Consolid8 is an add-on for [World of Warcraft](http://worldofwarcraft.com/).

Completing a dungeon in World of Warcraft can require considerable teamwork, and is often coordinated through the in-game chat window. Unfortunately, said chat window is often busy with other things:

> Reputation with Wyrmrest Accord increased by 13.
> Reputation with Wyrmrest Accord increased by 13.
> Your share of the loot is 5 Silver, 10 Copper.
> Reputation with Wyrmrest Accord increased by 13.
> Reputation with Wyrmrest Accord increased by 13.
> You receive loot: [Thick Fur Clothing Scraps]
> Your share of the loot is 1 Gold, 13 Silver, 52 Copper.

Your chat messages are mixed in with a slew of messages informing you of many relatively minor gains.


Consolid8 takes these messages and more, filters them, and only shows the important ones. The rest are counted up and summarised in a tooltip, and/or a report that appears when you finish your dungeon. This is how:

*	**Reputation**:
	Consolid8 counts the reputation that you gain, and displays it in the report. (Note: Consolid8 does not remove the reputation messages from your chat; to remove them, right-click the chat tab and click settings.)
*	**Loot**:
	When you loot a grey item, Consolid8 adds its vendor value to a total.

	Items that you get a lot of, like cloth, Vrykul Bones, Money, etc. are counted up (you can choose these items in the Interface Options). These messages are then hidden from your chat frame. Also, loot messages about other players (except loot rolls and wins) are hidden.

*	**Honor and Experience**:
	These are also counted.

*	**Crafting**:
	When you craft more than one item, Consolid8 counts how many you make and how many skill-ups they give you, and only displays two messages. For example:

	> Your skill in Tailoring has increased to 76.
	> You create: [Woolen Cape].
	> Your skill in Tailoring has increased to 77.
	> You create: [Woolen Cape].

	Becomes:

	> Your skill in Tailoring has increased to 77 (+2).
	> You create: [Woolen Cape]x2.

Installation
------------

**Users should download Consolid8 via [WoWInterface](http://wowinterface.com/downloads/info16236-Consolid8.html) or Curse, not via the Download ZIP button on GitHub.**

After downloading the ZIP from one of the sources above, extract it as usual into the `Interface/AddOns` subdirectory of your World of Warcraft installation folder.

Developers should clone the GitHub repository into their `Interface/AddOns` directory.

Usage
-----

A button is added over your chat frame (you can move or hide it if you like), and optionally on a broker display. Hovering over this will show a tooltip with the counts on it. A report is also displayed automatically when you leave a dungeon.

**Slash command**: `/consolid8`
**Switches**: `reset`, `report`, `show`, `hide`
