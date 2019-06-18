# frozen_string_literal: false
#
#   irb/input-method.rb - input methods used irb
#   	$Release Version: 0.9.6$
#   	$Revision$
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#
require_relative 'src_encoding'
require_relative 'magic-file'
require_relative 'completion'
require 'reline'

module IRB
  STDIN_FILE_NAME = "(line)" # :nodoc:
  class InputMethod

    # Creates a new input method object
    def initialize(file = STDIN_FILE_NAME)
      @file_name = file
    end
    # The file name of this input method, usually given during initialization.
    attr_reader :file_name

    # The irb prompt associated with this input method
    attr_accessor :prompt

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      IRB.fail NotImplementedError, "gets"
    end
    public :gets

    # Whether this input method is still readable when there is no more data to
    # read.
    #
    # See IO#eof for more information.
    def readable_after_eof?
      false
    end
  end

  class StdioInputMethod < InputMethod
    # Creates a new input method object
    def initialize
      super
      @line_no = 0
      @line = []
      @stdin = IO.open(STDIN.to_i, :external_encoding => IRB.conf[:LC_MESSAGES].encoding, :internal_encoding => "-")
      @stdout = IO.open(STDOUT.to_i, 'w', :external_encoding => IRB.conf[:LC_MESSAGES].encoding, :internal_encoding => "-")
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      print @prompt
      line = @stdin.gets
      @line[@line_no += 1] = line
    end

    # Whether the end of this input method has been reached, returns +true+ if
    # there is no more data to read.
    #
    # See IO#eof? for more information.
    def eof?
      @stdin.eof?
    end

    # Whether this input method is still readable when there is no more data to
    # read.
    #
    # See IO#eof for more information.
    def readable_after_eof?
      true
    end

    # Returns the current line number for #io.
    #
    # #line counts the number of times #gets is called.
    #
    # See IO#lineno for more information.
    def line(line_no)
      @line[line_no]
    end

    # The external encoding for standard input.
    def encoding
      @stdin.external_encoding
    end
  end

  # Use a File for IO with irb, see InputMethod
  class FileInputMethod < InputMethod
    # Creates a new input method object
    def initialize(file)
      super
      @io = IRB::MagicFile.open(file)
    end
    # The file name of this input method, usually given during initialization.
    attr_reader :file_name

    # Whether the end of this input method has been reached, returns +true+ if
    # there is no more data to read.
    #
    # See IO#eof? for more information.
    def eof?
      @io.eof?
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      print @prompt
      l = @io.gets
      l
    end

    # The external encoding for standard input.
    def encoding
      @io.external_encoding
    end
  end

  begin
    require "readline"
    class ReadlineInputMethod < InputMethod
      include Readline
      # Creates a new input method object using Readline
      def initialize
        super

        @line_no = 0
        @line = []
        @eof = false

        @stdin = IO.open(STDIN.to_i, :external_encoding => IRB.conf[:LC_MESSAGES].encoding, :internal_encoding => "-")
        @stdout = IO.open(STDOUT.to_i, 'w', :external_encoding => IRB.conf[:LC_MESSAGES].encoding, :internal_encoding => "-")

        if Readline.respond_to?("basic_word_break_characters=")
          Readline.basic_word_break_characters = IRB::InputCompletor::BASIC_WORD_BREAK_CHARACTERS
        end
        Readline.completion_append_character = nil
        Readline.completion_proc = IRB::InputCompletor::CompletionProc
      end

      # Reads the next line from this input method.
      #
      # See IO#gets for more information.
      def gets
        Readline.input = @stdin
        Readline.output = @stdout
        if l = readline(@prompt, false)
          HISTORY.push(l) if !l.empty?
          @line[@line_no += 1] = l + "\n"
        else
          @eof = true
          l
        end
      end

      # Whether the end of this input method has been reached, returns +true+
      # if there is no more data to read.
      #
      # See IO#eof? for more information.
      def eof?
        @eof
      end

      # Whether this input method is still readable when there is no more data to
      # read.
      #
      # See IO#eof for more information.
      def readable_after_eof?
        true
      end

      # Returns the current line number for #io.
      #
      # #line counts the number of times #gets is called.
      #
      # See IO#lineno for more information.
      def line(line_no)
        @line[line_no]
      end

      # The external encoding for standard input.
      def encoding
        @stdin.external_encoding
      end

      if Readline.respond_to?("basic_word_break_characters=")
        Readline.basic_word_break_characters = IRB::InputCompletor::BASIC_WORD_BREAK_CHARACTERS
      end
      Readline.completion_append_character = nil
      Readline.completion_proc = IRB::InputCompletor::CompletionProc
    end
  rescue LoadError
  end

  class ReidlineInputMethod < InputMethod
    include Reline
    # Creates a new input method object using Readline
    def initialize
      super

      @line_no = 0
      @line = []
      @eof = false

      @stdin = ::IO.open(STDIN.to_i, :external_encoding => IRB.conf[:LC_MESSAGES].encoding, :internal_encoding => "-")
      @stdout = ::IO.open(STDOUT.to_i, 'w', :external_encoding => IRB.conf[:LC_MESSAGES].encoding, :internal_encoding => "-")

      if Reline.respond_to?("basic_word_break_characters=")
        Reline.basic_word_break_characters = IRB::InputCompletor::BASIC_WORD_BREAK_CHARACTERS
      end
      Reline.completion_append_character = nil
      Reline.completion_proc = IRB::InputCompletor::CompletionProc
      Reline.output_modifier_proc =
        if IRB.conf[:USE_COLORIZE]
          proc do |output, complete:|
            next unless IRB::Color.colorable?
            IRB::Color.colorize_code(output, complete: complete)
          end
        else
          proc do |output|
            Reline::Unicode.escape_for_print(output)
          end
        end
      Reline.dig_perfect_match_proc = IRB::InputCompletor::PerfectMatchedProc
    end

    def check_termination(&block)
      @check_termination_proc = block
    end

    def dynamic_prompt(&block)
      @prompt_proc = block
    end

    def auto_indent(&block)
      @auto_indent_proc = block
    end

    # Reads the next line from this input method.
    #
    # See IO#gets for more information.
    def gets
      Reline.input = @stdin
      Reline.output = @stdout
      Reline.prompt_proc = @prompt_proc
      Reline.auto_indent_proc = @auto_indent_proc
      if l = readmultiline(@prompt, false, &@check_termination_proc)
        HISTORY.push(l) if !l.empty?
        @line[@line_no += 1] = l + "\n"
      else
        @eof = true
        l
      end
    end

    # Whether the end of this input method has been reached, returns +true+
    # if there is no more data to read.
    #
    # See IO#eof? for more information.
    def eof?
      super
    end

    # Whether this input method is still readable when there is no more data to
    # read.
    #
    # See IO#eof for more information.
    def readable_after_eof?
      true
    end

    # Returns the current line number for #io.
    #
    # #line counts the number of times #gets is called.
    #
    # See IO#lineno for more information.
    def line(line_no)
      @line[line_no]
    end

    # The external encoding for standard input.
    def encoding
      @stdin.external_encoding
    end
  end
end
