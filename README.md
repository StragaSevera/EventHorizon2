# EventHorizon 2

A rewrite of EventHorizon Continued for World of Warcraft 11.0 and beyond

## Why rewrite? Why don't continue under EventHorizon name?

This addon accumulated a lot of legacy over the years. Spaghetti code, huge files without any structure (the main file has 4600 lines of code!) - it is basically unmaintainable.

As a person who enjoys this addon so much that I cannot play WoW without it, I was left with a hard decision - either rewrite it from scratch, or abandon it and let it rot. I cannot "just patch it for TWW" and retain my sanity at the same time (which would be on brand with the expansion theme, but...) - so I decided to make it anew.

What will this give us? It will give up opportunities to improve this addon - even as radical as (gasp!) having a GUI configuration. That's right, in the (far) future there might be no need for a casual user to tinker with Lua code in the config files!

So, good luck to me. It will be long, hard, and I don't give any promises on when it will end. But it will be done. Eventually.

## Code style notes
### Imports and exports
This addon uses an ad-hoc structure where different files "talk" to each other only via imports and exports. At the top of the file there should be something like:

```lua
local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
```

And at the bottom there should be something like:

```lua
export("Frames", {
    frames = frames
})
```

The only place where we are allowed to mention the namespace table is the imports region. Why? Because we want our file dependencies to be explicit in order to have pressure to minimize them ;-)

### Capitalization

I'm not sure about it. For now I want the "global" things like frames and lifecycles to be capitalized, and the "local" things to be downcased.