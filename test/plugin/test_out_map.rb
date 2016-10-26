require 'helper'
require 'fluent/test/driver/output'

class MapOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    map "[tag, time, record]"
    multi false
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::MapOutput).configure(conf)
  end

  def test_tag_convert
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code' => '300'}

    d1 = create_driver %[
      map '["newtag", time, record]'
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 1, events.length
    assert_equal ["newtag", time.to_i, record], events[0]
  end

  def test_convert_multi_tag
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code' => '300'}

    d1 = create_driver %[
      map '[["tag1", time, record], ["tag2", time, record]]'
      multi true
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 2, events.length
    assert_equal ["tag1", time.to_i, record], events[0]
    assert_equal ["tag2", time.to_i, record], events[1]
  end

  def test_syntax_error
    tag = "tag"
    time = Time.local(2012, 10, 10, 10, 10, 0).to_i
    record = {'code' => '300'}

    #map is syntax error
    syntax_error_config = %[
      map tag.
    ]
    d1 = create_driver(syntax_error_config)
    es = Fluent::OneEventStream.new(time.to_i, record)
    e =  d1.instance.process(tag, es)
    assert e.kind_of?(SyntaxError)
  end

  def test_syntax_error2
    tag = "tag"
    time = Time.local(2012, 10, 10, 10, 10, 0).to_i
    record = {'code' => '300'}

    #map output lligal format
    syntax_error_config = %[
      map tag
    ]
    d1 = create_driver(syntax_error_config)
    es = Fluent::OneEventStream.new(time.to_i, record)
    e =  d1.instance.process(tag, es)
    assert e.kind_of?(SyntaxError)
  end

  def test_tag_convert_using_tag_time_record
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code' => '300'}

    d1 = create_driver %[
      tag '"newtag"'
      time time
      record record
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 1, events.length
    assert_equal ["newtag", time.to_i, record], events[0]
  end

  #deprected specification test
  def test_tag_convert_using_key_time_record
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code' => '300'}

    d1 = create_driver %[
      key '"newtag"'
      time time
      record record
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 1, events.length
    assert_equal ["newtag", time.to_i, record], events[0]
  end

  def test_config_error_tag
    _time = Time.local(2012, 10, 10, 10, 10, 0)
    _record = {'code' => '300'}

    #require time
    assert_raise(Fluent::ConfigError){
      create_driver %[
        time time
        record record
      ]
    }
  end

  def test_config_error_time
    _record = {'code' => '300'}

    #require time
    assert_raise(Fluent::ConfigError){
      create_driver %[
        tag '"newtag"'
        record record
      ]
    }
  end

  def test_config_error_record
    _time = Time.local(2012, 10, 10, 10, 10, 0)

    #require record
    assert_raise(Fluent::ConfigError){
      create_driver %[
        tag '"newtag"'
        time time
      ]
    }
  end

  def test_config_error_multi
    _time = Time.local(2012, 10, 10, 10, 10, 0)
    _record = {'code' => '300'}

    #require time
    assert_raise(Fluent::ConfigError){
      create_driver %[
        tag '"newtag"'
        time time
        record record
        multi true
      ]
    }
  end

  def test_timeout
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code' => '300'}

    d1 = create_driver %[
      key '"newtag"'
      time sleep 10
      record record
      timeout 1s
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 0, events.length
  end

  # Add format test
  ## test format type (map, record, maps)
  ## test Backward compatibility without format
  ##

  def test_convert_format_map
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code1' => '300', 'code2' => '400'}

    d1 = create_driver %[
      format map
      map '[["tag1", time, record["code1"]], ["tag2", time, record["code2"]]]'
      multi true
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 2, events.length
    assert_equal ["tag1", time.to_i, record["code1"]], events[0]
    assert_equal ["tag2", time.to_i, record["code2"]], events[1]
  end

  def test_tag_convert_format_record
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code' => '300'}

    d1 = create_driver %[
      format record
      tag '"newtag"'
      time time
      record record
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 1, events.length
    assert_equal ["newtag", time.to_i, record], events[0]
  end

  def test_convert_format_multimap
    tag = 'tag'
    time = Time.local(2012, 10, 10, 10, 10, 10).to_i
    record = {'code1' => '300', 'code2' => '400'}

    d1 = create_driver %[
      format multimap
      mmap1 '["tag1", time, record["code1"]]'
      mmap2 '["tag2", time, record["code2"]]'
    ]
    d1.run(default_tag: tag) do
      d1.feed(time, record)
    end
    events = d1.events
    assert_equal 2, events.length
    assert_equal ["tag1", time.to_i, record["code1"]], events[0]
    assert_equal ["tag2", time.to_i, record["code2"]], events[1]
  end
end
