# encoding: utf-8

require 'ruby_ami'
require 'adhearsion/rayo/connection/generic_connection'
require 'adhearsion/translator'

module Adhearsion
  module Rayo
    module Connection
      class Asterisk < GenericConnection
        attr_reader :ami_client, :translator
        attr_accessor :event_handler

        def initialize(options = {})
          @stream_options = options.values_at(:host, :port, :username, :password)
          @ami_client = new_ami_stream
          @translator_supervisor = Translator::Asterisk.supervise_as :ami_translator, @ami_client, self
          @translator = ActorHandle.new :ami_translator
          super()
        end

        def run
          start_ami_client
          raise DisconnectedError
        end

        def stop
          @translator_supervisor.terminate
          ami_client.terminate
        end

        def write(command, options)
          translator.async.execute_command command, options
        end

        def send_message(*args)
          translator.send_message *args
        end

        def handle_event(event)
          event_handler.call event
        end

        def new_ami_stream
          Celluloid::Actor[:ami_stream] = RubyAMI::Stream.new(*@stream_options, ->(event) { translator.async.handle_ami_event event }, logger)
          ActorHandle.new :ami_stream
        end

        def start_ami_client
          @ami_client = new_ami_stream unless ami_client.alive?
          ami_client.async.run
          Celluloid::Actor.join Celluloid::Actor[:ami_stream]
        end

        def new_call_uri
          Adhearsion.new_uuid
        end

        # Provides a handle to an Actor that can safely be cached/memoized without
        # risk of that handle becoming stale from a DeadActorError.
        #
        # * Requirement *:
        # The Actor must be put into the Celluloid::Actor Registry, which you are
        # responsible for setting up yourself.
        # @see https://github.com/celluloid/celluloid/wiki/Registry
        # @see https://github.com/celluloid/celluloid/wiki/Supervisors
        #
        # Example:
        #   require 'celluloid'
        #   class Clumsy
        #     include Celluloid
        #     def initialize
        #       puts "Clumsy ID badge # #{object_id} reporting for duty, sir!"
        #     end
        #   end
        #   supervisor = Clumsy.supervise_as :clumsy
        #   # Output: Clumsy ID badge # 2352 reporting for duty, sir!
        #
        #   clumsy_stale = Celluloid::Actor[:clumsy] # Don't cache clumsy_stale, he will eventually break!
        #   clumsy_fresh = ActorHandle.new :clumsy   # Use this instead!
        #
        #   clumsy_fresh.async.send :no_method_kaboom # Oh no! A DeadActor!
        #   # Output: NoMethodError: undefined method `no_method_kaboom' for #<Celluloid::ActorProxy(Clumsy:0x930)
        #   # Output: Clumsy ID badge # 2356 reporting for duty, sir!
        #   p clumsy_stale.alive? # Dead :(
        #   p clumsy_fresh.alive? # Not Dead! =)
        class ActorHandle
          def initialize(registered_name)
            @_registered_name = registered_name
            __actor__
          end

          def method_missing(method, *args, &block)
            __actor__.__send__(method, *args, &block)
          end

          def respond_to_missing?(method, include_private = false)
            __actor__.respond_to?(method) || super(method, include_private)
          end

          def async; __actor__.async end

          # def send_message(*args); fallback_handle.send_message(*args) end

          # Maintain a fallback handle to a Dead Actor.  Why?
          # Why? Because Celluloid::Actor[@_registered_name] will be Nil if the
          # Actor is terminated / de-registered.  And querying a Dead Actor is
          # better than querying Nil.
          def __actor__
            if handle = Celluloid::Actor[@_registered_name]
              return @_actor = handle
            end
            @_actor
          end
        end
      end
    end
  end
end
