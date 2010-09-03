require 'gserver'
module Adhearsion
  module VoIP
    class CallServer

      class RubyServer < GServer
        def initialize(port, host)
          super(port, host, (1.0/0.0)) # (1.0/0.0) == Infinity
        end

        def disconnecting(port)
          @call.deliver_message :cancel if !@call.nil?
          super(port)
        end

        def serve(io)
          begin
            call = Adhearsion.receive_call_from(io)
          rescue EOFError
            # We didn't get the initial headers we were expecting
            return
          end

          Events.trigger_immediately([call.originating_voip_platform, :before_call], call)
          Events.trigger_immediately([:call, :before_call], call)
          ahn_log.call.debug "Handling call with variables #{call.variables.inspect}"

          return DialPlan::ConfirmationManager.handle(call) if DialPlan::ConfirmationManager.confirmation_call?(call)

          # This is what happens 99.9% of the time.

          DialPlan::Manager.handle call
        rescue Hangup
          ahn_log.call "HANGUP event for call with uniqueid #{call.variables[:uniqueid].inspect} and channel #{call.variables[:channel].inspect}"
          Events.trigger_immediately([call.originating_voip_platform, :after_call], call)
          Events.trigger_immediately([:call, :after_call, call])
          call.hangup!
        rescue DialPlan::Manager::NoContextError => e
          ahn_log.call e.message
          call.hangup!
        rescue FailedExtensionCallException => failed_call
          begin
            ahn_log.call "Received \"failed\" meta-call with :failed_reason => #{failed_call.call.failed_reason.inspect}. Executing Executing /asterisk/failed_call event callbacks."
            Events.trigger [call.originating_voip_platform, :failed_call], failed_call.call
            Events.trigger [:call, :failed_call], failed_call.call
            call.hangup!
          rescue => e
            ahn_log.call.error e
          end
        rescue HungupExtensionCallException => hungup_call
          begin
            ahn_log.call "Received \"h\" meta-call. Executing /asterisk/hungup_call event callbacks."
            Events.trigger [call.originating_voip_platform, :hungup_call], hungup_call.call
            Events.trigger [:call, :hungup_call], hungup_call.call
            call.hangup!
          rescue => e
            ahn_log.call.error e
          end
        rescue UselessCallException
          ahn_log.call "Ignoring meta-AGI request"
          call.hangup!
        # TBD: (may have more hooks than what Jay has defined in hooks.rb)
        rescue => e
          ahn_log.call.error "#{e.class}: #{e.message}"
          ahn_log.call.error e.backtrace.join("\n\t")
        ensure
          Adhearsion.remove_inactive_call call rescue nil
        end

      end

      DEFAULT_OPTIONS = { :server_class => RubyServer, :port => 4573, :host => "0.0.0.0" } unless defined? DEFAULT_OPTIONS
      attr_reader :host, :port, :server_class, :server

      def initialize(options = {})
        options                     = DEFAULT_OPTIONS.merge options
        @host, @port, @server_class = options.values_at(:host, :port, :server_class)
        @server                     = server_class.new(port, host)
      end

      def start
        server.audit = true
        server.start
      end

      def graceful_shutdown
        if @shutting_down
          server.stop
          return
        end

        @shutting_down = true

        while server.connections > 0
          sleep 0.2
        end

        server.stop
      end

      def shutdown
        server.shutdown
      end

      def stop
        server.stop
      end

      def join
        server.join
      end
    end
  end
end