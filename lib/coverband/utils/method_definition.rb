# frozen_string_literal: true

if defined?(RubyVM::AbstractSyntaxTree)
  module Coverband
    module Utils
      class MethodDefinition
        attr_reader :path
        def initialize(path)
          @path = path
        end

        def scan
          scan_node(RubyVM::AbstractSyntaxTree.parse_file(path))
        end

        def self.scan(path)
          MethodDefinition.new(path).scan
        end

        private

        def scan_node(node)
          return [] unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
          definitions = []
          if node.type == :DEFN
            definitions <<
              OpenStruct.new(
                first_line_number: node.first_lineno,
                last_line_number: node.last_lineno
              )
          end
          definitions +
            node.children.flatten.compact.map { |child|
              scan_node(child)
            }.flatten
        end
      end
    end
  end
end
