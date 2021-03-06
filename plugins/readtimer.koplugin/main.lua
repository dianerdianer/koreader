local InfoMessage = require("ui/widget/infomessage")
local TimeWidget = require("ui/widget/timewidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local ReadTimer = WidgetContainer:new{
    name = "readtimer",
    time = 0,  -- The expected time of alarm if enabled, or 0.
}

function ReadTimer:init()
    self.alarm_callback = function()
        if self.time == 0 then return end -- How could this happen?
        self.time = 0
        UIManager:show(InfoMessage:new{
            text = T(_("Read timer alarm\nTime's up. It's %1 now."), os.date("%c")),
        })
    end
    self.ui.menu:registerToMainMenu(self)
end

function ReadTimer:scheduled()
    return self.time ~= 0
end

function ReadTimer:remainingMinutes()
    if self:scheduled() then
        return os.difftime(self.time, os.time()) / 60
    else
        return math.huge
    end
end

function ReadTimer:remainingTime()
    if self:scheduled() then
        local remain_time = os.difftime(self.time, os.time()) / 60
        local remain_hours = math.floor(remain_time / 60)
        local remain_minutes = math.floor(remain_time - 60 * remain_hours)
        return remain_hours, remain_minutes
    end
end

function ReadTimer:unschedule()
    if self:scheduled() then
        UIManager:unschedule(self.alarm_callback)
        self.time = 0
    end
end

function ReadTimer:addToMainMenu(menu_items)
    menu_items.read_timer = {
        text_func = function()
            if self:scheduled() then
                return T(_("Read timer (%1m)"),
                    string.format("%.2f", self:remainingMinutes()))
            else
                return _("Read timer")
            end
        end,
        checked_func = function()
            return self:scheduled()
        end,
        sub_item_table = {
            {
                text = _("Time"),
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local now_t = os.date("*t")
                    local curr_hour = now_t.hour
                    local curr_min = now_t.min
                    local curr_sec_from_midnight = curr_hour*3600 + curr_min*60
                    local time_widget = TimeWidget:new{
                        hour = curr_hour,
                        min = curr_min,
                        ok_text = _("Set timer"),
                        title_text =  _("Set reader timer"),
                        callback = function(time)
                            touchmenu_instance:closeMenu()
                            self:unschedule()
                            local timer_sec_from_mignight = time.hour*3600 + time.min*60
                            local seconds
                            if timer_sec_from_mignight > curr_sec_from_midnight then
                                seconds = timer_sec_from_mignight - curr_sec_from_midnight
                            else
                                seconds = 24*3600 - (curr_sec_from_midnight - timer_sec_from_mignight)
                            end
                            if seconds > 0 and seconds < 18*3600 then
                                self.time = os.time() + seconds
                                UIManager:scheduleIn(seconds, self.alarm_callback)
                                local hr_str = ""
                                local min_str = ""
                                local hr = math.floor(seconds/3600)
                                if hr > 0 then
                                    hr_str = T(N_("1 hour", "%1 hours", hr), hr)
                                end
                                local min = math.floor((seconds%3600)/60)
                                if min > 0 then
                                    min_str = T(N_("1 minute", "%1 minutes", min), min)
                                    if hr_str ~= "" then
                                        hr_str = hr_str .. " "
                                    end
                                end
                                UIManager:show(InfoMessage:new{
                                    text = T(_("Timer set to: %1:%2.\n\nThat's %3%4 from now."),
                                        string.format("%02d", time.hour), string.format("%02d", time.min),
                                        hr_str, min_str),
                                    timeout = 5,
                                })
                            --current time or time > 18h
                            elseif seconds == 0 or seconds >= 18*3600 then
                                UIManager:show(InfoMessage:new{
                                    text = _("Timer could not be set. You have selected current time or time in past"),
                                    timeout = 5,
                                })
                            end
                        end
                    }
                    UIManager:show(time_widget)
                end,
            },
            {
                text = _("Minutes from now"),
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local remain_time = {}
                    local remain_hours, remain_minutes = self:remainingTime()
                    if not remain_hours and not remain_minutes then
                        remain_time = G_reader_settings:readSetting("reader_timer_remain_time")
                        if remain_time then
                            remain_hours = remain_time[1]
                            remain_minutes = remain_time[2]
                        end
                    end
                    local time_widget = TimeWidget:new{
                        hour = remain_hours or 0,
                        min = remain_minutes or 0,
                        hour_max = 17,
                        ok_text = _("Set timer"),
                        title_text =  _("Set reader timer from now (hours:minutes)"),
                        callback = function(time)
                            touchmenu_instance:closeMenu()
                            self:unschedule()
                            local seconds = time.hour * 3600 + time.min * 60
                            if seconds > 0 then
                                self.time = os.time() + seconds
                                UIManager:scheduleIn(seconds, self.alarm_callback)
                                local hr_str = ""
                                local min_str = ""
                                local hr = time.hour
                                if hr > 0 then
                                    hr_str = T(N_("1 hour", "%1 hours", hr), hr)
                                end
                                local min = time.min
                                if min > 0 then
                                    min_str = T(N_("1 minute", "%1 minutes", min), min)
                                    if hr_str ~= "" then
                                        hr_str = hr_str .. " "
                                    end
                                end
                                UIManager:show(InfoMessage:new{
                                    text = T(_("Timer set for %1%2."), hr_str, min_str),
                                    timeout = 5,
                                })
                                remain_time = {hr, min}
                                G_reader_settings:saveSetting("reader_timer_remain_time", remain_time)
                            end
                        end
                    }
                    UIManager:show(time_widget)
                end,
            },
            {
                text = _("Stop timer"),
                keep_menu_open = true,
                enabled_func = function()
                    return self:scheduled()
                end,
                callback = function(touchmenu_instance)
                    self:unschedule()
                    touchmenu_instance:updateItems()
                end,
            },
        },
    }
end

return ReadTimer
