-- This system allows hierarchy management of entities, ui elements, or any sort of parentable object without needing to store any hierarchy information in those objects themselves.
-- This system is weak-keyed, so when all objects of a hierarchy are no longer referenced anywhere else this system will not prevent them from being freed by the garbage collector.

local collectgarbage = collectgarbage
local pairs = pairs

local children_lookup = setmetatable( {}, { __mode="k" } )
local parent_lookup = setmetatable( {}, { __mode="k" } )
local cleanup_queue = setmetatable( {}, { __mode="k" } )

local function GetParent( obj )
	return parent_lookup[ obj ]
end

local function SetParent( obj, new_parent_obj )
	local old_parent_obj = GetParent( obj )
	if ( old_parent_obj == new_parent_obj ) then
		return
	end
	if ( old_parent_obj ) then
		local old_family = children_lookup[ old_parent_obj ]
		for i=1, #old_family do
			if ( old_family[ i ] == obj ) then
				--  Removing a child won't immediately shift anything, it just sets the field as false and makes note that the family needs cleanup. This is for safe iteration.
				old_family[ i ] = false
				cleanup_queue[ old_parent_obj ] = true
				break
			end
		end
	end
	if ( new_parent_obj ) then
		local new_family = children_lookup[ new_parent_obj ]
		if ( not new_family ) then
			new_family = {}
			children_lookup[ new_parent_obj ] = new_family
		end
		table.insert( new_family, obj )
	end
	parent_lookup[ obj ] = new_parent_obj
end

local function GetChildren( obj )
	if ( children_lookup[ obj ] ) then
		return table.Copy( children_lookup[ obj ] )
	end
end

local function GetChildren_ReadOnly( obj )
	return children_lookup[ obj ]
end

-- Do not add or remove children while iterating.
local function ChildIterator( obj )
	
	local children = GetChildren_ReadOnly( obj )
	if ( not children ) then
		return function() end
	end
	local i=0
	local child_count=#children
	return function()
		i=i+1
		while ( not children[i] ) do -- Skip over children that have been removed.
			if ( i > child_count ) then
				return nil
			end
			i=i+1
		end
		return children[i]
	end
end

local function Cleanup( obj )
	local children = children_lookup[ obj ]
	local i=1
	while ( children[ i ] ~= nil ) do
		if ( not children[ i ] ) then -- If false, this means a child was removed from this slot and further children should be shifted down.
			table.remove( children, i )
		else
			i = i + 1
		end
	end
	if ( #children == 0 ) then -- Don't keep the table if the object no longer has children.
		children_lookup[ obj ] = nil
	end
	cleanup_queue[ obj ] = nil
end

local function CleanupAll()
	collectgarbage( "stop" )
	for obj,_ in pairs( cleanup_queue ) do
		Cleanup( obj )
	end
	collectgarbage( "restart" )
end

-- Warning: This should not be called during iteration!
local function SortChildren( obj, sorter_func )
	local children = children_lookup[ obj ]
	if ( not children ) then
		return
	end
	collectgarbage( "stop" )
	Cleanup( obj )
	collectgarbage( "restart" )
	table.sort( children_lookup[ obj ], sorter_func )
end

return {
	ChildIterator = ChildIterator,
	GetParent = GetParent,
	SetParent = SetParent,
	GetChildren = GetChildren,
	GetChildren_ReadOnly = GetChildren_ReadOnly,
	CleanupAll = CleanupAll,
	SortChildren = SortChildren
}