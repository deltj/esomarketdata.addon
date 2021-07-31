ESOMarketData = {}
ESOMarketData.name = "ESOMarketData"
ESOMarketData.variableVersion = 1
ESOMarketData.scraping = false
ESOMarketData.savedVars = nil

EMDItemInfo = {}
function EMDItemInfo:New(itemLink, itemName, quality, stackCount, sellerName, timeRemaining, purchasePrice, itemUniqueId, purchasePricePerUnit)
    local itemInfo = {}
    itemInfo.itemLink               = itemLink
    itemInfo.sellerName             = sellerName
    itemInfo.itemName               = itemName
    itemInfo.quality                = quality
    itemInfo.stackCount             = stackCount
    itemInfo.purchasePrice          = purchasePrice
    itemInfo.itemUniqueId           = itemUniqueId
    itemInfo.timeRemaining          = timeRemaining
    itemInfo.purchasePricePerUnit   = purchasePricePerUnit
    return itemInfo
end

function ESOMarketData:ProcessTradingHouseResponse()
    local numItemsOnPage, currentPage, hasMorePages = GetTradingHouseSearchResultsInfo()
    d("numItemsOnPage: " .. numItemsOnPage)
    d("currentPage: " .. currentPage)

    -- Check if the scan is complete
    if numItemsOnPage > 0 then
        -- Process items on this page
        for i = 1, numItemsOnPage do
            local itemLink = GetTradingHouseSearchResultItemLink(i)
            local icon, itemName, quality, stackCount, sellerName, timeRemaining, purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit = GetTradingHouseSearchResultItemInfo(i)
            local itemInfo = EMDItemInfo:New(itemLink, itemName, quality, stackCount, sellerName, timeRemaining, purchasePrice, itemUniqueId, purchasePricePerUnit)

            --foo = {}
            --foo.name = itemName
            --foo.uid = Id64ToString(itemUniqueId)

            table.insert(self.savedVars.marketData, itemInfo)
        end
    else
        -- No more pages/items, scan is complete
        d('Scrape complete')
        self.scraping = false
    end
end

function ESOMarketData:ScrapePage(page)
    if self.scraping then
        d("Scraping page: " .. page)

        -- Request a page of data so we can scrape it
        ExecuteTradingHouseSearch(page)

        -- Schedule the scrape of the next page some time in the future
        d("TradingHouseCooldown: " .. GetTradingHouseCooldownRemaining())
        local delay = math.max(GetTradingHouseCooldownRemaining() + 1000, 5000)
        d("delay for next page: " .. delay)
        zo_callLater(function()	ESOMarketData:ScrapePage(page + 1) end, delay)
    end
end

function ESOMarketData:ScrapeTrader()
    d("Starting scrape")
    ClearAllTradingHouseSearchTerms()
    self.scraping = true
    ESOMarketData:ScrapePage(1)
end

local function OnTradingHouseOpened()
    d("OnTradingHouseOpened")

    -- Add a button to the keybind strip to start scraping this trader
    if (not KEYBIND_STRIP:HasKeybindButton(ESOMarketData.buttons.scrapeButton)) then
		KEYBIND_STRIP:AddKeybindButton(ESOMarketData.buttons.scrapeButton)
	end
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

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ESOMarketData.name then return end
    EVENT_MANAGER:UnregisterForEvent(ESOMarketData.name, EVENT_ADD_ON_LOADED)
    ESOMarketData:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ESOMarketData.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)