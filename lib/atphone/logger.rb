#!/usr/bin/env ruby

# Logs messages to STDOUT
class ATPhone::Logger
    attr_reader :time_format

    # Set _log_ to true if you want messages logged
    #
    # _time_format_ controls how time is printed (see Time#strftime)
    def initialize(log, time_format="%Y-%m-%d %H:%M:%S")
        @log = log
        @time_format = time_format
    end

    def log(msg)
        puts "[ATPhone|%s] %s" % [Time.now.strftime(@time_format), msg] if @log
    end
end
