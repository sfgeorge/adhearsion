require 'eventmachine'
require 'adhearsion/voip/dsl/dialplan/thread_mixin'
require 'adhearsion/voip/dsl/dialplan/parser'
require 'adhearsion/voip/dsl/dialplan/dispatcher'
#require 'adhearsion/voip/freeswitch/basic_connection_manager'
#require 'adhearsion/voip/freeswitch/freeswitch_dialplan_command_factory'

module Adhearsion
  module VoIP
    module FreeSWITCH
      module EventSocket
        module OESServer

          class << self

            def graceful_shutdown
              ahn_log.oes.info "Shutting down Outbound EventSocket listener"
              EventMachine::stop_event_loop
            end

            def start(port, host)
             EventMachine::run {
               EventMachine::start_server host, port, self
               ahn_log.oes.info "Opening FreeSWITCH Outbound EventSocket listener on #{host}:#{port}"
             }
            end

          end

          def post_init
            @buffer = ""
            @pipe_out, @pipe_in = IO.pipe
            send_message("connect")

            Thread.new do
              begin
                call = Adhearsion.receive_call_from(@pipe_out)

                # TODO A lot of this is duplicate code from AGI::Server.
                # Consolidate this so we don't repeat ourselves

                # FIXME: This event should probably not be freeswitch-specific
                # Same is true in AGI::Server
                Events.trigger_immediately([:freeswitch, :before_call], call)
                ahn_log.oes.debug "Handling call with variables #{call.variables.inspect}"

                return DialPlan::ConfirmationManager.handle(call) if DialPlan::ConfirmationManager.confirmation_call?(call)

                # This is what happens 99.9% of the time.

                DialPlan::Manager.handle call
              rescue Hangup
                ahn_log.oes.info "HANGUP event for call with uniqueid #{call.variables[:uniqueid].inspect} and channel #{call.variables[:channel].inspect}"
                # FIXME: This event should probably not be freeswitch-specific
                Events.trigger_immediately([:freeswitch, :after_call], call)
                call.hangup!
              rescue DialPlan::Manager::NoContextError => e
                ahn_log.oes.error e
                call.hangup!
              rescue FailedExtensionCallException => failed_call
                begin
                  ahn_log.oes.info "Received \"failed\" meta-call with :failed_reason => #{failed_call.call.failed_reason.inspect}. Executing Executing /freeswitch/failed_call event callbacks."
                  # FIXME: This event should probably not be freeswitch-specific
                  Events.trigger [:freeswitch, :failed_call], failed_call.call
                  call.hangup!
                rescue => e
                  ahn_log.oes.error e
                end
              rescue HungupExtensionCallException => hungup_call
                begin
                  ahn_log.agi.info "Received \"h\" meta-call. Executing /freeswitch/hungup_call event callbacks."
                  # FIXME: This event should probably not be freeswitch-specific
                  Events.trigger [:freeswitch, :hungup_call], hungup_call.call
                  call.hangup!
                rescue => e
                  ahn_log.oes.error e
                end
              rescue UselessCallException
                ahn_log.oes.info "Ignoring meta-OES request"
                call.hangup!
              # TBD: (may have more hooks than what Jay has defined in hooks.rb)
              rescue => e
                ahn_log.oes.error "#{e.class}: #{e.message}"
                ahn_log.oes.error e.backtrace.join("\n\t")
              ensure
                Adhearsion.remove_inactive_call call rescue nil
              end
            end
          end

          def receive_data(data)
            @buffer << data
            while message = @buffer.slice!( /^[^\n]*[\n]/m )
              message.chomp!
              ahn_log.oes.debug "<<< #{message}"
              @pipe_in.print message + "\n"
            end
          end

          def send_message(message)
            ahn_log.oes.debug ">>> #{message}"
            send_data(message + "\n\n")
          end
        end
      end
    end
  end
end
