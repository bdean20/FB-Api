PriorityQueue = {
    __index = {
        put = function(self, priority, object)
            local queue = self[priority]
            if not queue then
                queue = {first = 1, last = 0}
                self[priority] = queue
            end
            queue.last = queue.last + 1
            queue[queue.last] = object
        end,
        pop = function(self)         
            for priority, queue in pairs(self) do
                if queue.first <= queue.last then
                    local object = queue[queue.first]
                    queue[queue.first] = nil
                    queue.first = queue.first + 1
                    return priority, object
                else
                    self[priority] = nil
                end
            end
        end
    },
    __call = function(cls)
        return setmetatable({}, cls)
    end
}
 
setmetatable(PriorityQueue, PriorityQueue)