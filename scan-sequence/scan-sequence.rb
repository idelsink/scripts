#!/usr/bin/env ruby
# scan-sequence sequence-file output-path

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

class ScanSequence
    def initialize()
        puts "init scan".blue
    end
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

        if scans.to_i > 1
            if zero_padding == "true"
                filename+=(scans.to_i-@scan_count.to_i).to_s.rjust(scans.size, '0')
            else
                filename+=(scans.to_i-@scan_count.to_i).to_s
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
                run = true
                while run
                    cmd = command.get()
                    unless cmd.empty?
                        puts "command: #{cmd}".blue
                        system( "cd "+output_path+" && "+cmd )
                        puts "".red
                        puts "command returned: #{$?.exitstatus}".blue
                    else
                        puts "#{section} done".yellow
                        run=false
                    end
                end
            end
        end
    rescue IniParse::IniParseError
        puts "Error parsing the INI file".red
    end
rescue ArgumentError => e
    puts e.message.red
rescue Exception => e
    puts e.message.red
    puts "backtrace:\n\t#{e.backtrace.join("\n\t")}"
end
