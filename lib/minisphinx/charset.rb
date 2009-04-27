module Minisphinx
  class Charset
    attr_reader :type, :only, :except
    
    def initialize(opts)
      @type     = opts[:type] || :standard
      @only     = Array(opts[:only]).to_set   if opts[:only]
      @except   = Array(opts[:except]).to_set if opts[:except]
    end
      
    def self.charset
      if @charset.nil?
        @charset = DeepHash.new
        YAML.load_file(RAILS_ROOT + '/config/sphinx/charset.yml').each do |type, table|
          type = type.to_sym
          table.each do |group, charset|
            group = group.to_sym
            charset.split(',').each do |char|
              key, value = char.strip.split('->')
              @charset[type][group][key] = value 
            end
          end
        end
      end
      @charset
    end
  
    MAX_PER_LINE = 50
    def to_s
      chars = []
      self.class.charset[type].each do |group, charset|
        next if except and except.include?(group)
        next if only and not only.include?(group)

        charset.each do |key, value|
          chars << (value ? "#{key}->#{value}" : key)
        end
      end

      lines = []
      chars.sort.each_slice(MAX_PER_LINE) do |line_chars|
        lines << line_chars.join(', ')
      end
      lines.join(", \\\n")
    end

    class DeepHash < Hash
      def initialize
        super do |hash, key|
          hash[key] = DeepHash.new
        end
      end
    end
  end
end
