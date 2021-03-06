module Preferences
  # Represents the definition of a preference for a particular model
  class PreferenceDefinition
    # The data type for the content stored in this preference type
    attr_reader :type

    def initialize(name, *args) #:nodoc:
      options = args.extract_options!
      options.assert_valid_keys(:default, :group_defaults)
      
      @type = args.first ? args.first.to_sym : :boolean

      case @type
      when :any
        @klass = "ActiveRecord::Type::Value".constantize.new
      when :datetime
        @klass = "ActiveRecord::Type::DateTime".constantize.new
      else
        @klass = "ActiveRecord::Type::#{@type.to_s.classify}".constantize.new
      end

      # Create a column that will be responsible for typecasting
      @column = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, options[:default], @klass)

      @group_defaults = (options[:group_defaults] || {}).inject({}) do |defaults, (group, default)|
        defaults[group.is_a?(Symbol) ? group.to_s : group] = type_cast(default)
        defaults
      end
    end

    # The name of the preference
    def name
      @column.name
    end

    # The default value to use for the preference in case none have been
    # previously defined
    def default_value(group = nil)
      @group_defaults.include?(group) ? @group_defaults[group] : type_cast(@column.default)
    end

    # Determines whether column backing this preference stores numberic values
    def number?
      @column.type == :integer || @column.type == :float
    end

    # Typecasts the value based on the type of preference that was defined.
    # This uses ActiveRecord's typecast functionality so the same rules for
    # typecasting a model's columns apply here.
    def type_cast(value)
      return 1      if @type == :integer && value == true
      return 0      if @type == :integer && value == false
      return true   if @type == :boolean && (value == 't' || value == true)
      return false  if @type == :boolean && (value == 'f' || value == false)
      if @type == :any
        value
      else
        @klass.respond_to?(:deserialize) ? @klass.deserialize(value) : @column.type_cast_from_database(value)
      end
    end

    # Typecasts the value to true/false depending on the type of preference
    def query(value)
      if !(value = type_cast(value))
        false
      elsif number?
        !value.zero?
      else
        !value.blank?
      end
    end
  end
end
