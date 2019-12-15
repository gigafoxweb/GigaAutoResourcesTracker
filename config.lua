local addonName, addonData = ...

addonData.config = {}

addonData.config.trackersList = {
    -- proffesions
    {
        name = 'find-minerals',
        id = 2580,
        priority = 1000
    },
    {
        name = 'find-herbs',
        id = 2383,
        priority = 500
    },
    -- hunter trackers
    {
        name = 'hunter-track-hidden',
        id = 19885,
        priority = 400
    },
    {
        name = 'hunter-track-humanoids',
        id = 19883,
        priority = 398
    },
    {
        name = 'hunter-track-beasts',
        id = 1494,
        priority = 399
    },
    {
        name = 'hunter-track-undead',
        id = 19884,
        priority = 398
    },
    {
        name = 'hunter-track-giants',
        id = 19882,
        priority = 397
    },
    {
        name = 'hunter-track-elementals',
        id = 19880,
        priority = 396
    },
    {
        name = 'hunter-track-dragonkin',
        id = 19879,
        priority = 395
    },
    {
        name = 'hunter-track-demons',
        id = 19878,
        priority = 394
    },
    -- druid
    {
        name = 'druid-track-humanoids',
        id = 5225,
        priority = 350
    },
    -- dwarf
    {
        name = 'find-treasure',
        id = 2481,
        priority = 300
    }
}
