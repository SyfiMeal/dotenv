require "dotenv/parser"
require "dotenv/environment"
require "dotenv/missing_keys"

# The top level Dotenv module. The entrypoint for the application logic.
module Dotenv
  class << self
    attr_accessor :instrumenter
  end

  module_function

  # Loads environment variables from one or more `.env` files. See `#parse` for more details.
  def load(*filenames, **kwargs)
    parse(*filenames, **kwargs) do |env|
      instrument("dotenv.load", env: env) { env.apply }
    end
  end

  # Same as `#load`, but raises Errno::ENOENT if any files don't exist
  def load!(*filenames)
    load(*filenames, ignore: false)
  end

  # same as `#load`, but will overwrite existing values in `ENV`
  def overwrite(*filenames)
    load(*filenames, overwrite: true)
  end
  alias_method :overload, :overwrite
  module_function :overload

  # same as `#overwrite`, but raises Errno::ENOENT if any files don't exist
  def overwrite!(*filenames)
    load(*filenames, overwrite: true, ignore: false)
  end
  alias_method :overload!, :overwrite!
  module_function :overload!

  # Parses the given files, yielding for each file if a block is given.
  #
  # @param filenames [String, Array<String>] Files to parse
  # @param overwrite [Boolean] Overwrite existing `ENV` values
  # @param ignore [Boolean] Ignore non-existent files
  # @param block [Proc] Block to yield for each parsed `Dotenv::Environment`
  # @return [Hash] parsed key/value pairs
  def parse(*filenames, overwrite: false, ignore: true, &block)
    filenames << ".env" if filenames.empty?
    filenames = filenames.reverse if overwrite

    filenames.reduce({}) do |hash, filename|
      begin
        env = Environment.new(File.expand_path(filename), overwrite: overwrite)
        env = block.call(env) if block
      rescue Errno::ENOENT
        raise unless ignore
      end

      hash.merge! env || {}
    end
  end

  def instrument(name, payload = {}, &block)
    if instrumenter
      instrumenter.instrument(name, payload, &block)
    else
      yield
    end
  end

  def require_keys(*keys)
    missing_keys = keys.flatten - ::ENV.keys
    return if missing_keys.empty?
    raise MissingKeys, missing_keys
  end
end

require "dotenv/rails" if defined?(Rails::Railtie)
