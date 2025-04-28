module ResponseParser
  extend ActiveSupport::Concern

  # Returns the main ID from the API response.
  def response_id
    case selected_provider
    when "Openai"
      response&.dig("id")
    # when "Anthropic" # TODO: Add Anthropic logic
    #   response&.dig("id")
    else
      nil
    end
  end

  # Returns the usage hash from the API response.
  def response_usage
    case selected_provider
    when "Openai"
      response&.dig("usage")
    # when "Anthropic" # TODO: Add Anthropic logic
    #   response&.dig("usage")
    else
      nil
    end
  end

  # Helper methods for specific usage stats
  def response_input_tokens
    response_usage&.dig("input_tokens")
  end

  def response_output_tokens
    response_usage&.dig("output_tokens")
  end

  def response_total_tokens
    response_usage&.dig("total_tokens")
  end

  # Returns the model string used in the API response.
  def response_model_used
    case selected_provider
    when "Openai"
      response&.dig("model")
    # when "Anthropic" # TODO: Add Anthropic logic
    #   response&.dig("model") # Or appropriate path
    else
      nil
    end
  end

  # Returns the primary text output from the response.
  # This might need refinement based on endpoint_type for some providers.
  def response_output_text
    # Ensure response is parsed if stored as a string
    parsed_response = response.is_a?(String) ? JSON.parse(response) : response

    case selected_provider
    when "Openai"
      # Assuming Chat endpoint for now based on the example
      parsed_response&.dig("output", 0, "content", 0, "text")
      # when "Anthropic" # TODO: Add Anthropic logic
      # Example: parsed_response&.dig("content", 0, "text")
    else
      nil
    end
  rescue JSON::ParserError
    nil # Handle cases where response is not valid JSON
  end

  # Returns the full output block(s) from the response.
  def response_output
     parsed_response = response.is_a?(String) ? JSON.parse(response) : response

     case selected_provider
     when "Openai"
       parsed_response&.dig("output")
       # when "Anthropic"
       # parsed_response&.dig("content")
     else
       nil
     end
   rescue JSON::ParserError
     nil
  end

  # Returns a standardized hash representing the API response,
  # abstracting provider-specific structures.
  def responses2
    return nil unless response.present?

    parsed_response = response.is_a?(String) ? JSON.parse(response) : response
    standardized_response = { output: [] } # Initialize with empty output array

    case selected_provider
    when "Openai"
      # Extract top-level info
      standardized_response[:id] = parsed_response["id"]
      standardized_response[:model] = parsed_response["model"]

      # Handle function call responses
      if parsed_response["output"]&.first&.dig("type") == "function_call"
        standardized_response[:type] = "function_call"
        standardized_response[:role] = nil

        output_item = {}
        output_item[:id] = parsed_response["output"].first["id"]
        output_item[:type] = "function_call"
        output_item[:tool_name] = parsed_response["output"].first["name"]
        output_item[:tool_parameters] = JSON.parse(parsed_response["output"].first["arguments"])
        standardized_response[:output] << output_item.compact
      else
        # Handle regular message responses
        first_output_message = parsed_response.dig("output", 0)
        standardized_response[:role] = first_output_message&.dig("role")
        standardized_response[:type] = first_output_message&.dig("type")

        content_items = first_output_message&.dig("content") || []
        content_items.each do |item|
          output_item = {}
          output_item[:id] = nil
          output_item[:type] = item["type"] == "output_text" ? "text" : item["type"]
          output_item[:text] = item["text"] if output_item[:type] == "text"
          output_item[:url] = nil
          if item["type"] == "function_call"
            output_item[:tool_name] = item["name"]
            output_item[:tool_parameters] = item["arguments"]
          end
          standardized_response[:output] << output_item.compact
        end
      end

    when "Anthropic"
      # Extract top-level info
      standardized_response[:id] = parsed_response["id"]
      standardized_response[:model] = parsed_response["model"]
      standardized_response[:role] = parsed_response["role"]
      standardized_response[:type] = parsed_response["type"] # e.g., "message"

      # Process content items
      content_items = parsed_response["content"] || []
      content_items.each do |item|
        output_item = {}
        output_item[:id] = item["id"] # Available for tool_use, maybe nil for text
        output_item[:type] = item["type"] # e.g., "text", "tool_use"
        output_item[:text] = item["text"] if item["type"] == "text"
        output_item[:url] = nil # Placeholder
        output_item[:tool_name] = item["name"] if item["type"] == "tool_use"
        output_item[:tool_parameters] = item["input"] if item["type"] == "tool_use"
        standardized_response[:output] << output_item.compact # Remove nil values
      end

    else
      # Unknown provider or response format doesn't match expected structure
      return nil
    end

    standardized_response

  rescue JSON::ParserError
    # Handle cases where response is not valid JSON
    nil
  end
end
