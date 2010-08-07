require 'adhearsion/voip/menu_state_machine/menu_class'

module Adhearsion
  module VoIP
    module Freeswitch
      module Commands

        include Adhearsion::VoIP::Freeswitch::EventSocket::Parser

        def answer
          execute("answer")
        end

        def hangup

        end

        def dial(dest, options = {})
          args = []
          *recognized_options = :caller_id, :name, :for, :options, :confirm
          unrecognized_options = options.keys - recognized_options
          raise ArgumentError, "Unknown dial options: #{unrecognized_options.to_sentence}" if unrecognized_options.any?

          set_caller_id_name options[:name]
          set_caller_id_number options[:caller_id]
          confirm_option = dial_macro_option_compiler options[:confirm]
          all_options = options[:options]
          all_options = all_options ? all_options + confirm_option : confirm_option

          execute("bridge", args)
        end

        def play(*arguments)
          arguments.flatten.each do |argument|
            play_time(argument) || play_numeric(argument) || play_string(argument)
          end
        end

        def play_time(argument)
          if argument.kind_of? Time
            execute(:say, argument.to_i)
          end
        end

        def play_numeric(argument)
          if argument.kind_of?(Numeric) || argument =~ /^\d+$/
            execute(:say, ["number", argument])
          end
        end

        def play_string(argument)
          execute(:playback, argument)
        end

        def execute(app, args = [])
          uuid = @call.variables[:unique_id] ? @call.variables[:unique_id] : ""
          message  = "sendmsg %s\n" % uuid
          message += "call-command: execute\n"
          message += "execute-app-name: %s\n" % app.to_s
          message += "execute-app-arg: %s" % args.join(" ")
          send_message(message)
          read_response
        end

      end
    end
  end
end