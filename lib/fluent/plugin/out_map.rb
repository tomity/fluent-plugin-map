require 'fluent/plugin/output'

module Fluent::Plugin
  class MapOutput < Output
    Fluent::Plugin.register_output('map', self)

    helpers :event_emitter

    # Define `router` method of v0.12 to support v0.10 or earlier
    unless method_defined?(:router)
      define_method("router") { Fluent::Engine }
    end

    config_param :map, :string, :default => nil
    config_param :tag, :string, :default => nil
    config_param :key, :string, :default => nil #deprecated
    config_param :time, :string, :default => nil
    config_param :record, :string, :default => nil
    config_param :multi, :bool, :default => false
    config_param :timeout, :time, :default => 1
    config_param :format, :string, :default => nil

    MMAP_MAX_NUM = 50

    def configure(conf)
      super
      @format = determine_format()
      configure_format()
      @map = create_map(conf)
    end

    def determine_format()
      if @format
        @format
      elsif @map
        "map"
      elsif (@tag || @key) && @time && @record
        "record"
      else
        raise Fluent::ConfigError, "Any of map, 3 parameters(tag, time, and record) or format is required "
      end
    end

    def configure_format()
      case @format
      when "map"
        # pass
      when "record"
        @tag ||= @key
        raise Fluent::ConfigError, "multi and 3 parameters(tag, time, and record) are not compatible" if @multi
      when "multimap"
        # pass.
      else
        raise Fluent::ConfigError, "format #{@format} is invalid."
      end
    end

    def create_map(conf)
      # return string like double array.
      case @format
      when "map"
        parse_map()
      when "record"
        "[[#{@tag}, #{@time}, #{@record}]]"
      when "multimap"
        parse_multimap(conf)
      end
    end

    def parse_map()
      if @multi
        @map
      else
        "[#{@map}]"
      end
    end

    def parse_multimap(conf)
      check_mmap_range(conf)

      prev_mmap = nil
      result_mmaps = (1..MMAP_MAX_NUM).map { |i|
        mmap = conf["mmap#{i}"]
        if (i > 1) && prev_mmap.nil? && !mmap.nil?
          raise ConfigError, "Jump of mmap index found. mmap#{i - 1} is missing."
        end
        prev_mmap = mmap
        next if mmap.nil?

        mmap
      }.compact.join(',')
      "[#{result_mmaps}]"
    end

    def check_mmap_range(conf)
      invalid_mmap = conf.keys.select { |k|
        m = k.match(/^mmap(\d+)$/)
        m ? !((1..MMAP_MAX_NUM).include?(m[1].to_i)) : false
      }
      unless invalid_mmap.empty?
        raise ConfigError, "Invalid mmapN found. N should be 1 - #{MMAP_MAX_NUM}: " + invalid_mmap.join(",")
      end
    end


    def process(tag, es)
      begin
        tag_output_es = do_map(tag, es)
        tag_output_es.each_pair do |output_tag, output_es|
          router.emit_stream(output_tag, output_es)
        end
        tag_output_es
      rescue SyntaxError => e
        $log.error "map command is syntax error: #{@map}"
        e #for test
      end
    end

    def do_map(tag, es)
      tuples = generate_tuples(tag, es)

      tag_output_es = Hash.new{|h, key| h[key] = Fluent::MultiEventStream::new}
      tuples.each do |output_tag, time, record|
        if time == nil || record == nil
          raise SyntaxError.new
        end
        tag_output_es[output_tag].add(time, record)
        $log.trace { [output_tag, time, record].inspect }
      end
      tag_output_es
    end

    def generate_tuples(tag, es)
      tuples = []
      es.each {|time, record|
        new_tuple = eval(@map)
        tuples.concat new_tuple
      }
      tuples
    end

    def timeout_block(tag, time, record)
      begin
        Timeout.timeout(@timeout){
          yield
        }
      rescue Timeout::Error
        $log.error {"Timeout: #{Time.at(time)} #{tag} #{record.inspect}"}
      end
    end
  end
end
