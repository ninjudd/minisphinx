require 'deep_hash'

module Minisphinx
  class Charset
    attr_reader :type, :only, :except

    def initialize(opts)
      @type     = opts[:type] || :standard
      @only     = Array(opts[:only]).to_set   if opts[:only]
      @except   = Array(opts[:except]).to_set if opts[:except]
    end

    def self.charset
      @charset ||= YAML.load_file(RAILS_ROOT + '/config/sphinx/charset.yml')
    end

    MAX_PER_LINE = 50
    def to_s
      chars = {}

      self.class.charset[type.to_s].each do |charset|
        charset.each do |group, charset|
          next if except and except.include?(group)
          next if only and not only.include?(group)
          pp group
          charset.split(',').each do |char|
            key = char.strip.split('->').first
            chars[key] ||= char
          end
        end
      end

      lines = []
      chars.values.flatten.sort.each_slice(MAX_PER_LINE) do |line_chars|
        lines << line_chars.join(', ')
      end
      lines.join(", \\\n")
    end
  end
end
