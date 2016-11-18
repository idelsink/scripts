#!/usr/bin/env ruby
##########################################################################
# script name: scan-sequence
# script version: 0.1.0
# script date: 18 November 2016
# website: https://github.com/idelsink/scripts
##########################################################################
#
# A script that will run multiple scan commands in sequence.
# The commands are defined in a file that uses the simple ini format.
#
# Usage:
#   scan-sequence sequence-file output-path
##########################################################################
# MIT License
#
# Copyright (c) 2016 Ingmar Delsink
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
##########################################################################
# load dependencies
begin
    require 'colorize'
rescue LoadError
    abort("error while loading 'colorize'")
end
begin
    require 'iniparse'
rescue LoadError
    abort("error while loading 'iniparse'")
end
begin
    require 'fileutils'
rescue LoadError
    abort("error while loading 'fileutils'")
end

class CommandParameters
    private
    variables=[
        :name,
        :scans,
        :zero_padding,
        :scan_comm,
        :format,
        :mode,
        :depth,
        :resolution,
        :geometry,
        :scan_comm_p,
        :save_comm,
        :ext,
        :pause_before_scan,
        :disabled
    ]
    public
    variables.each do |variable|
        #instance_variable_set("@" + variable.to_s, "")
        define_method(variable) { |*arg|
            if arg.length == 1
                instance_variable_set("@" + variable.to_s, arg)
            else
                # check if array, else string
                var =  instance_variable_get("@"+variable.to_s)
                if var.kind_of?(Array)
                    return var.join(' ')
                else
                    return instance_variable_get("@"+variable.to_s)
                end
            end
        }
    end
    private
    def create_method(name, &block)
        self.class.send(:define_method, name, &block)
    end
end
# input scan
class ScanCommand
    def initialize()
        @scan_count=0
        @default=CommandParameters.new()
        @current=CommandParameters.new()
    end
    def set_default(default_command_hash)
        @default = hash_to_parameters(default_command_hash)
        @scan_count=(@current.scans()||@default.scans()).to_i
    end
    def set(command_hash)
        @current = hash_to_parameters(command_hash)
        @scan_count=(@current.scans()||@default.scans()).to_i
    end
    def get()
        if((@current.disabled()||@default.disabled())=="true")
            return ""
        end
        # check scan count [<= 0 means ask]
        if (@current.scans()||@default.scans()).to_i<=0
            if ((@current.scans()||@default.scans()).to_i)<=0
                puts "How many scans do you want to make? [scans > 0]".yellow
                scans=""
                loop do
                    scans=STDIN.gets
                    break if scans.to_i>0
                    puts "wrong input"
                end
                @current.scans(scans.to_i)
            end
            @scan_count=(@current.scans()||@default.scans()).to_i
        end
        scans=@current.scans()||@default.scans()
        # filename
        basename=(@current.name()||@default.name())
        if basename.empty?
            basename="scan"
        end

        zero_padding =@current.zero_padding || @default.zero_padding()

        filename=basename
        filename_count=(scans.to_i-@scan_count.to_i+1).to_s

        if scans.to_i > 1
            if zero_padding == "true"
                filename+=filename_count.rjust(scans.size, '0')
            else
                filename+=filename_count
            end
        end

        command=""
        command+=@current.scan_comm()   || @default.scan_comm()
        command+=" "
        command+=@current.format()      || @default.format()
        command+=" "
        command+=@current.mode()        || @default.mode()
        command+=" "
        command+=@current.depth()       || @default.depth()
        command+=" "
        command+=@current.resolution()  || @default.resolution()
        command+=" "
        command+=@current.geometry()    || @default.geometry()
        command+=" "
        command+=@current.scan_comm_p() || @default.scan_comm_p()
        command+=" "
        command+=@current.save_comm()   || @default.save_comm()
        command+=" "
        command+=filename
        command+=@current.ext()         || @default.ext()

        if @scan_count>=1
            @scan_count-=1
            return command
        else
            return ""
        end
    end
    # user input constants
    SKIP="s"
    SKIP_SECTION="ss"
    ESC="\e"
    CANCEL="c"
    def pause_before_scan(section)
        if ((@current.pause_before_scan()||@default.pause_before_scan())=="true")
            puts "[#{section}]".light_yellow
            puts "press \'s\' to skip this scan.".blue
            puts "press \'ss\' to skip the remaining scans in this section".blue
            puts "press \'c\' or \'ESC\' to cancel/exit this program".blue
            puts "press any unlisted key to scan".blue
            return STDIN.gets.chomp
        else
            return ""
        end
    end
    private
    def hash_to_parameters(hash)
        command = CommandParameters.new()
        hash.each do |key, value|
            command.method(key).call(value)
        end
        return command
    end
end

begin
    command = ScanCommand.new()
    config_file = ARGV[0]
    raise ArgumentError, "no config file given".red if config_file.nil?
    raise ArgumentError, "supplied config file doesn't exists".red if ! File.exist?(config_file)
    output_path = ARGV[1]||"./"
    raise ArgumentError, "supplied output path doesn't exists".red if ! File.exist?(output_path)

    begin
        IniParse.parse( File.read(config_file)).to_hash.each do |section, hash|
            if section == "default"
                command.set_default(hash)
            else
                command.set(hash)
                run_section = true
                while run_section
                    cmd = command.get()
                    unless cmd.empty?
                        puts "----------------------------------------".light_cyan
                        puts "command to run: #{cmd}".green
                        case command.pause_before_scan(section)
                        when ScanCommand::SKIP
                            # skip this scan
                            puts "skipping scan".cyan
                        when ScanCommand::SKIP_SECTION
                            # skip this section
                            run_section=false
                            puts "skipping [#{section}]".cyan
                        when ScanCommand::ESC
                            exit 0
                        else
                            puts "running scan".light_green
                            start = Time.now
                            # no PID is caught. So no killing of this sub-process
                            system( "cd "+output_path+" && "+cmd ) or raise "command exited with error"
                            puts ""
                            finish = Time.now
                            puts "time taken: #{(finish - start).round(2)}".blue
                        end
                        puts ""
                    else
                        run_section=false
                        puts "[#{section}]".yellow+" done".green
                    end
                end
            end
        end
    rescue IniParse::IniParseError
        puts "Error parsing the INI file".red
    end
rescue ArgumentError => e
    puts e.message.red
rescue StandardError => e
    puts e.message.red
    puts "backtrace:\n\t#{e.backtrace.join("\n\t")}"
rescue SystemExit, Interrupt
    puts "scan-sequence is now done".magenta
end
