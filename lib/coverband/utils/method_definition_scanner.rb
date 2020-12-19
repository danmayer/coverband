# frozen_string_literal: true

if defined?(RubyVM::AbstractSyntaxTree)
  module Coverband
    module Utils
      class MethodDefinitionScanner
        attr_reader :path

        def initialize(path)
          @path = path
        end

        def scan
          scan_node(RubyVM::AbstractSyntaxTree.parse_file(path))
        end

        def self.scan(path)
          new(path).scan
        end

        class MethodBody
          def initialize(method_definition)
            @method_definition = method_definition
          end

          def coverage?(file_coverage)
            body_coverage = file_coverage[(first_line_number - 1)..(last_line_number - 1)]
            body_coverage.map(&:to_i).any?(&:positive?)
          end

          private

          def first_line_number
            @method_definition.first_line_number + 1
          end

          def last_line_number
            @method_definition.last_line_number - 1
          end
        end

        class MethodDefinition
          attr_reader :last_line_number, :first_line_number

          def initialize(first_line_number:, last_line_number:)
            @first_line_number = first_line_number
            @last_line_number = last_line_number
          end

          def body
            MethodBody.new(self)
          end
        end

        private

        def scan_node(node)
          return [] unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
          definitions = []
          if node.type == :DEFN
            definitions <<
              MethodDefinition.new(
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
