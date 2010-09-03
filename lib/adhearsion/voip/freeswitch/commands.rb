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
            execute(:say, "en", "short_date_time", "pronounced", argument.to_i)
          end
        end

        def play_numeric(argument)
          if argument.kind_of?(Numeric) || argument =~ /^\d+$/
            execute(:say, "en", "number", "pronounced", argument)
          end
        end

        def play_string(argument)
          execute(:playback, argument)
        end

        # Backward compatibility with Asterisk/AGI
        def say_digits(digits)
          execute(:say, "en", "number", "iterated", digits)
        end

        def execute(app, *args)
          uuid = @call.variables[:unique_id] ? @call.variables[:unique_id] : ""
          message  = "sendmsg %s\n" % uuid
          message += "call-command: execute\n"
          message += "execute-app-name: %s\n" % app.to_s
          message += "execute-app-arg: %s" % args.join(" ") if !args.empty?
          write message
          read
        end

        def api(cmd, *args)
          message  = "sendmsg\n"
          message += "api %s %s" % [cmd.to_s, args.join(" ")]
          write message
          read
        end

        # Used to receive keypad input from the user. Digits are collected
        # via DTMF (keypad) input until one of three things happens:
        #
        #  1. The number of digits you specify as the first argument is collected
        #  2. The timeout you specify with the :timeout option elapses.
        #  3. The "#" key (or the key you specify with :accept_key) is pressed
      	#
      	# Usage examples
      	#
      	#   input   # Receives digits until the caller presses the "#" key
      	#   input 3 # Receives three digits. Can be 0-9, * or #
      	#   input 5, :accept_key => "*"   # Receive at most 5 digits, stopping if '*' is pressed
      	#   input 1, :timeout => 1.minute # Receive a single digit, returning an empty
      	#                                   string if the timeout is encountered
      	#   input 9, :timeout => 7, :accept_key => "0" # Receives nine digits, returning
      	#                                              # when the timeout is encountered
      	#                                              # or when the "0" key is pressed.
      	#   input 3, :play => "you-sound-cute"
      	#   input :play => ["if-this-is-correct-press", 1, "otherwise-press", 2]
      	#
      	# When specifying files to play, the playback of the sequence of files will stop
      	# immediately when the user presses the first digit.
      	#
      	# The :timeout option works like a digit timeout, therefore each digit pressed
      	# causes the timer to reset. This is a much more user-friendly approach than an
        # absolute timeout.
      	#
        # Note that when the digit limit is not specified the :accept_key becomes "#".
        # Otherwise there would be no way to end the collection of digits. You can
      	# obviously override this by passing in a new key with :accept_key.
        def input(*args)

          options = args.last.kind_of?(Hash) ? args.pop : {}
          number_of_digits = args.shift

          sound_files     = Array options.delete(:play) || "n/a" # CHANGE
          timeout         = options.delete(:timeout) || 5 # CHANGE
          terminating_key = options.delete(:accept_key) || "#" # CHANGE
          terminating_key = if terminating_key
            terminating_key.to_s
          elsif number_of_digits.nil? && !terminating_key.equal?(false)
            '#'
          end

          if number_of_digits && number_of_digits < 0
            ahn_log.agi.warn "Giving -1 to input() is now deprecated. Don't specify a first " +
                             "argument to simulate unlimited digits." if number_of_digits == -1
            raise ArgumentError, "The number of digits must be positive!"
          end

          buffer = ''
          #key = sound_files.any? ? interruptible_play(*sound_files) || '' : wait_for_digit(timeout || -1)

          execute(:play_and_get_digits, 0, number_of_digits, 1, timeout * 1000, terminating_key, "${base_dir}/sounds/en/us/callie/zrtp/8000/zrtp-enroll_welcome.wav", "x", "adhearsion_digits", '(\*#\d)+')
          #execute(:play_and_get_digits, 0, number_of_digits, 1, timeout * 1000, terminating_key, "zrtp/zrtp-enroll_welcome.wav", "x", "adhearsion_digits", '(\*#\d)+')

          api(:uuid_getvar, @call.variables[:Channel_Unique_ID], "adhearsion_digits")

#          loop do
#            return buffer if key.nil?
#            if terminating_key
#              if key == terminating_key
#                return buffer
#              else
#                buffer << key
#                return buffer if number_of_digits && number_of_digits == buffer.length
#              end
#            else
#              buffer << key
#              return buffer if number_of_digits && number_of_digits == buffer.length
#            end
#            key = wait_for_digit(timeout || -1)
#          end
      	end

        def set_variable(varname, value)
          execute(:set, varname, value)
        end

        def get_variable(varname)
          execute(:get, varname)
        end

        private

        def write(message)
          message.split("\n").each do |line|
            ahn_log.oes.debug ">>> #{line}"
          end
          ahn_log.oes.debug ">>>"
          @call.io.print message + "\n\n"
        end

        def read
          res = read_response
          ahn_log.oes.debug "<<< #{res["reply_text"]}"
          return true if res["reply_text"].downcase == "+ok"
          return false
        end

      end
    end
  end
end