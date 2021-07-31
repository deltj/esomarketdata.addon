ESOMarketData = {}
ESOMarketData.name = "ESOMarketData"
ESOMarketData.variableVersion = 1
ESOMarketData.scraping = false
ESOMarketData.minPageDelay = 2000
ESOMarketData.currentPage = 1
ESOMarketData.savedVars = nil

CurrentTraderInfo = {}

function ESOMarketData:ProcessTradingHouseResponse()
    local numItemsOnPage, currentPage, hasMorePages = GetTradingHouseSearchResultsInfo()
    d("numItemsOnPage: " .. numItemsOnPage)
    d("currentPage: " .. currentPage)

    -- Record the date/time at which we observe each listing
    local timestamp = os.time()

    -- Check if the scan is complete
    if numItemsOnPage > 0 then
        -- Process items on this page
        for i = 1, numItemsOnPage do

            -- From the index (i) we can now gather info about this listing

            -- Get item link
            local itemLink = GetTradingHouseSearchResultItemLink(i)

            -- Get basic info about the listing
            local icon, itemName, quality, stackCount, sellerName, timeRemaining, purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit = GetTradingHouseSearchResultItemInfo(i)
            local uid = Id64ToString(itemUniqueId)

            -- Create a new object to represent this listing
            local listing = {}
            listing.guildId                 = CurrentTraderInfo.guildId
            listing.guildName               = CurrentTraderInfo.guildName
            listing.npcName                 = CurrentTraderInfo.npcName
            listing.timestamp               = timestamp
            listing.itemLink                = itemLink
            listing.sellerName              = sellerName
            listing.itemName                = itemName
            listing.quality                 = quality
            listing.stackCount              = stackCount
            listing.purchasePrice           = purchasePrice
            listing.itemUniqueId            = itemUniqueId
            listing.timeRemaining           = timeRemaining
            listing.purchasePricePerUnit    = purchasePricePerUnit

            -- Add the listing to the marketData table
            table.insert(self.savedVars.marketData, listing)
        end

        -- Schedule the scrape of the next page some time in the future
        d("TradingHouseCooldown: " .. GetTradingHouseCooldownRemaining())
        local delay = math.max(GetTradingHouseCooldownRemaining() + 100, self.minPageDelay)
        d("delay for next page: " .. delay)
        self.currentPage = self.currentPage + 1
        zo_callLater(function()	ESOMarketData:ScrapePage(self.currentPage) end, delay)
    else
        -- No more pages/items, scan is complete
        d('Scrape complete')
        self.scraping = false
    end
end

function ESOMarketData:ScrapePage(page)
    if self.scraping then
        d("Scraping page: " .. page)

        -- Request a page of data from the trader so we can scrape it
        ExecuteTradingHouseSearch(page)
    end
end

-- This function clears the search terms (so we get a full listing for this trader) and starts page processing
function ESOMarketData:ScrapeTrader()
    d("Starting scrape")

    ClearAllTradingHouseSearchTerms()

    -- Start the scrape
    self.scraping = true
    self.currentPage = 1
    ESOMarketData:ScrapePage(self.currentPage)
end

local function OnTradingHouseOpened()
    d("OnTradingHouseOpened")

    -- Add a button to the keybind strip to start scraping this trader
    if (not KEYBIND_STRIP:HasKeybindButton(ESOMarketData.buttons.scrapeButton)) then
		KEYBIND_STRIP:AddKeybindButton(ESOMarketData.buttons.scrapeButton)
	end

    -- Get trader background info
    local guildId, guildName, guildAlliance = GetCurrentTradingHouseGuildDetails()
    CurrentTraderInfo.guildId = guildId
    CurrentTraderInfo.guildName = guildName

    -- Get the trader NPC name so we can lookup the location
    local unitName = zo_strformat(SI_UNIT_NAME, GetRawUnitName("interact"))
    CurrentTraderInfo.npcName = unitName
end

local function OnTradingHouseClosed()
    d("OnTradingHouseClosed")

    -- Cancel any running scrape
    ESOMarketData.scraping = false
end

local function OnTradingHouseResponseReceived(eventCode, responseType, result)
    d("OnTradingHouseResponseReceived response type: " .. responseType)

    -- We have received a trading house response, deal with it
    ESOMarketData:ProcessTradingHouseResponse()
end

function ESOMarketData:Initialize()
    -- Configure saved variables
    self.savedVars = ZO_SavedVars:NewAccountWide("ESOMarketDataVars", ESOMarketData.variableVersion, nil, ESOMarketData.default, GetWorldName())
    --if self.savedVars.marketData == nil then
        self.savedVars.marketData = {}
    --end

    -- Prepare the scrape button
    self.buttons = {}
	self.buttons.scrapeButton = {
		name = "Scrape Price Data",
		keybind = "UI_SHORTCUT_PRIMARY",
		callback = function() ESOMarketData:ScrapeTrader() end,
		alignment = KEYBIND_STRIP_ALIGN_CENTER,
	}

    -- Register event handlers
    EVENT_MANAGER:RegisterForEvent(self.Name, EVENT_OPEN_TRADING_HOUSE, OnTradingHouseOpened)
    EVENT_MANAGER:RegisterForEvent(self.Name, EVENT_CLOSE_TRADING_HOUSE, OnTradingHouseClosed)
    EVENT_MANAGER:RegisterForEvent(self.Name, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, OnTradingHouseResponseReceived)
end

-- Event handler for EVENT_ADD_ON_LOADED; this is essentially the program entry point
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ESOMarketData.name then return end

    -- addonName matches, so we've been loaded.  No need to be registered for this event any longer
    EVENT_MANAGER:UnregisterForEvent(ESOMarketData.name, EVENT_ADD_ON_LOADED)

    -- Initialize the addon
    ESOMarketData:Initialize()
end

-- Register for EVENT_ADD_ON_LOADED, which is called each time an addon is loaded
EVENT_MANAGER:RegisterForEvent(ESOMarketData.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)