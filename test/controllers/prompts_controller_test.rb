require "test_helper"

class PromptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @prompt = prompts(:one)
  end

  test "should get index" do
    get prompts_url
    assert_response :success
  end

  test "should get new" do
    get new_prompt_url
    assert_response :success
  end

  test "should create prompt" do
    assert_difference("Prompt.count") do
      post prompts_url, params: { prompt: { background_prompt: @prompt.background_prompt, flow_id: @prompt.flow_id, foreground_prompt: @prompt.foreground_prompt, keep_original_background: @prompt.keep_original_background, light_source_direction: @prompt.light_source_direction, light_source_strength: @prompt.light_source_strength, negative_prompt: @prompt.negative_prompt, original_background_depth: @prompt.original_background_depth, output_format: @prompt.output_format, preserve_original_subject: @prompt.preserve_original_subject, seed: @prompt.seed } }
    end

    assert_redirected_to prompt_url(Prompt.last)
  end

  test "should show prompt" do
    get prompt_url(@prompt)
    assert_response :success
  end

  test "should get edit" do
    get edit_prompt_url(@prompt)
    assert_response :success
  end

  test "should update prompt" do
    patch prompt_url(@prompt), params: { prompt: { background_prompt: @prompt.background_prompt, flow_id: @prompt.flow_id, foreground_prompt: @prompt.foreground_prompt, keep_original_background: @prompt.keep_original_background, light_source_direction: @prompt.light_source_direction, light_source_strength: @prompt.light_source_strength, negative_prompt: @prompt.negative_prompt, original_background_depth: @prompt.original_background_depth, output_format: @prompt.output_format, preserve_original_subject: @prompt.preserve_original_subject, seed: @prompt.seed } }
    assert_redirected_to prompt_url(@prompt)
  end

  test "should destroy prompt" do
    assert_difference("Prompt.count", -1) do
      delete prompt_url(@prompt)
    end

    assert_redirected_to prompts_url
  end
end
