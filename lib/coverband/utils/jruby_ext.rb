# frozen_string_literal: true

####
# This exists in CRuby, but not in JRuby, so add it
#
# Taken from: https://github.com/ruby/ruby/blob/c5eb24349a4535948514fe765c3ddb0628d81004/ext/coverage/lib/coverage.rb
####
module Coverage
  def self.line_stub(file)
    lines = File.foreach(file).map { nil }
    iseqs = [RubyVM::InstructionSequence.compile_file(file)]
    until iseqs.empty?
      iseq = iseqs.pop
      iseq.trace_points.each { |n, type| lines[n - 1] = 0 if type == :line }
      iseq.each_child { |child| iseqs << child }
    end
    lines
  end
end
