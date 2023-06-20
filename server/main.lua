-- Global state table
local globalState = {}

if ESX.GetConfig().OxInventory then
	AddEventHandler('onServerResourceStart', function(resourceName)
		if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
			local stashes = MySQL.query.await('SELECT * FROM addon_inventory')

			for i = 1, #stashes do
				local stash = stashes[i]
				local jobStash = stash.name:find('society') and string.sub(stash.name, 9)
				exports.ox_inventory:RegisterStash(stash.name, stash.label, 100, 200000, stash.shared == 0 and true or false, jobStash)
			end
		end
	end)

	globalState.Items = {} -- Global state variable
	globalState.InventoriesIndex, globalState.Inventories, globalState.SharedInventories = {}, {}, {}

	MySQL.ready(function()
		local items = MySQL.query.await('SELECT * FROM items')

		for i = 1, #items, 1 do
			globalState.Items[items[i].name] = items[i].label
		end

		local result = MySQL.query.await('SELECT * FROM addon_inventory')

		for i = 1, #result, 1 do
			local name = result[i].name
			local label = result[i].label
			local shared = result[i].shared

			local result2 = MySQL.query.await('SELECT * FROM addon_inventory_items WHERE inventory_name = @inventory_name', {
				['@inventory_name'] = name
			})

			if shared == 0 then
				table.insert(globalState.InventoriesIndex, name)

				globalState.Inventories[name] = {}
				local items = {}

				for j = 1, #result2, 1 do
					local itemName = result2[j].name
					local itemCount = result2[j].count
					local itemOwner = result2[j].owner

					if items[itemOwner] == nil then
						items[itemOwner] = {}
					end

					table.insert(items[itemOwner], {
						name = itemName,
						count = itemCount,
						label = globalState.Items[itemName]
					})
				end

				for k, v in pairs(items) do
					local addonInventory = CreateAddonInventory(name, k, v)
					table.insert(globalState.Inventories[name], addonInventory)
				end
			else
				local items = {}

				for j = 1, #result2, 1 do
					table.insert(items, {
						name = result2[j].name,
						count = result2[j].count,
						label = globalState.Items[result2[j].name]
					})
				end

				local addonInventory = CreateAddonInventory(name, nil, items)
				globalState.SharedInventories[name] = addonInventory
			end
		end
	end)
end

function GetInventory(name, owner)
	for i = 1, #globalState.Inventories[name], 1 do
		if globalState.Inventories[name][i].owner == owner then
			return globalState.Inventories[name][i]
		end
	end
end

function GetSharedInventory(name)
	return globalState.SharedInventories[name]
end

function AddSharedInventory(society)
	if type(society) ~= 'table' or not society?.name or not society?.label then
		return
	end

	-- Addon inventory
	MySQL.Async.execute('INSERT INTO addon_inventory (name, label, shared) VALUES (@name, @label, @shared)', {
		['name'] = society.name,
		['label'] = society.label,
		['shared'] = 1
	})

	globalState.SharedInventories[society.name] = CreateAddonInventory(society.name, nil, {})
end

AddEventHandler('esx_addoninventory:getInventory', function(name, owner, cb)
	cb(GetInventory(name, owner))
end)

AddEventHandler('esx_addoninventory:getSharedInventory', function(name, cb)
	cb(GetSharedInventory(name))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
	local addonInventories = {}

	for i = 1, #globalState.InventoriesIndex, 1 do
		local name = globalState.InventoriesIndex[i]
		local inventory = GetInventory(name, xPlayer.identifier)

		if inventory == nil then
			inventory = CreateAddonInventory(name, xPlayer.identifier, {})
			table.insert(globalState.Inventories[name], inventory)
		end

		table.insert(addonInventories, inventory)
	end

	xPlayer.set('addonInventories', addonInventories)
end)
