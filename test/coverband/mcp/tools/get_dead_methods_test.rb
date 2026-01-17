# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetDeadMethodsTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
      end
    end

    def teardown
      super
      Coverband.configuration.store.clear! if Coverband.configuration.store
    end

    test "tool has correct metadata" do
      assert_equal "Get Dead Methods", Coverband::MCP::Tools::GetDeadMethods.title
      assert_includes Coverband::MCP::Tools::GetDeadMethods.description, "methods that have never been executed"
    end

    test "input schema has optional file_pattern parameter" do
      schema = Coverband::MCP::Tools::GetDeadMethods.input_schema
      assert_instance_of ::MCP::Tool::InputSchema, schema
    end

    if defined?(RubyVM::AbstractSyntaxTree)
      test "call returns dead methods when AST support available" do
        mock_dead_methods = [
          {
            file_path: "/app/models/user.rb",
            class_name: "User",
            method_name: "unused_method",
            line_number: 10
          },
          {
            file_path: "/app/models/user.rb", 
            class_name: "User",
            method_name: "another_unused",
            line_number: 15
          },
          {
            file_path: "/app/models/order.rb",
            class_name: "Order",
            method_name: "dead_method",
            line_number: 20
          }
        ]

        Coverband::Utils::DeadMethods.expects(:scan_all).returns(mock_dead_methods)

        response = Coverband::MCP::Tools::GetDeadMethods.call(server_context: {})

        assert_instance_of ::MCP::Tool::Response, response
        
        result = JSON.parse(response.content.first[:text])
        
        assert_equal 3, result["total_dead_methods"]
        assert_equal 2, result["files_with_dead_methods"]
        assert_nil result["file_pattern"]
        
        # Check grouped results
        user_file = result["results"].find { |f| f["file"] == "/app/models/user.rb" }
        assert_equal 2, user_file["dead_methods"].length
        
        order_file = result["results"].find { |f| f["file"] == "/app/models/order.rb" }
        assert_equal 1, order_file["dead_methods"].length
        
        # Check method details
        user_method = user_file["dead_methods"].first
        assert_equal "User", user_method["class_name"]
        assert_equal "unused_method", user_method["method_name"]
        assert_equal 10, user_method["line_number"]
      end

      test "call filters by file_pattern when provided" do
        mock_dead_methods = [
          {
            file_path: "/app/models/user.rb",
            class_name: "User",
            method_name: "unused_method",
            line_number: 10
          },
          {
            file_path: "/app/helpers/user_helper.rb",
            class_name: "UserHelper", 
            method_name: "dead_helper",
            line_number: 5
          }
        ]

        Coverband::Utils::DeadMethods.expects(:scan_all).returns(mock_dead_methods)

        response = Coverband::MCP::Tools::GetDeadMethods.call(
          file_pattern: "app/models/**/*.rb",
          server_context: {}
        )

        result = JSON.parse(response.content.first[:text])
        
        # Should only include the models file
        assert_equal 1, result["total_dead_methods"]
        assert_equal 1, result["files_with_dead_methods"]
        assert_equal "app/models/**/*.rb", result["file_pattern"]
        
        assert_equal 1, result["results"].length
        assert_equal "/app/models/user.rb", result["results"].first["file"]
      end

      test "call handles no dead methods found" do
        Coverband::Utils::DeadMethods.expects(:scan_all).returns([])

        response = Coverband::MCP::Tools::GetDeadMethods.call(server_context: {})

        result = JSON.parse(response.content.first[:text])
        
        assert_equal 0, result["total_dead_methods"]
        assert_equal 0, result["files_with_dead_methods"]
        assert_empty result["results"]
      end
    end

    test "call returns error when AST support not available" do
      # Temporarily hide the constant
      if defined?(RubyVM::AbstractSyntaxTree)
        original_ast = RubyVM::AbstractSyntaxTree
        RubyVM.send(:remove_const, :AbstractSyntaxTree)
      end

      begin
        response = Coverband::MCP::Tools::GetDeadMethods.call(server_context: {})

        assert_instance_of ::MCP::Tool::Response, response
        assert_includes response.content.first[:text], "requires Ruby 2.6+ with RubyVM::AbstractSyntaxTree"
      ensure
        # Restore the constant if it was defined
        if defined?(original_ast)
          RubyVM.const_set(:AbstractSyntaxTree, original_ast)
        end
      end
    end

    test "call handles errors gracefully" do
      if defined?(RubyVM::AbstractSyntaxTree)
        Coverband::Utils::DeadMethods.expects(:scan_all).raises(StandardError.new("Test error"))

        response = Coverband::MCP::Tools::GetDeadMethods.call(server_context: {})

        assert_instance_of ::MCP::Tool::Response, response
        assert response.is_error
        assert_includes response.content.first[:text], "Error analyzing dead methods: Test error"
      end
    end
  end
end