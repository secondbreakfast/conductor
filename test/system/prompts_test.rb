require "application_system_test_case"

class PromptsTest < ApplicationSystemTestCase
  setup do
    @prompt = prompts(:one)
  end

  test "visiting the index" do
    visit prompts_url
    assert_selector "h1", text: "Prompts"
  end

  test "should create prompt" do
    visit prompts_url
    click_on "New prompt"

    fill_in "Background prompt", with: @prompt.background_prompt
    fill_in "Flow", with: @prompt.flow_id
    fill_in "Foreground prompt", with: @prompt.foreground_prompt
    check "Keep original background" if @prompt.keep_original_background
    fill_in "Light source direction", with: @prompt.light_source_direction
    fill_in "Light source strength", with: @prompt.light_source_strength
    fill_in "Negative prompt", with: @prompt.negative_prompt
    fill_in "Original background depth", with: @prompt.original_background_depth
    fill_in "Output format", with: @prompt.output_format
    fill_in "Preserve original subject", with: @prompt.preserve_original_subject
    fill_in "Seed", with: @prompt.seed
    click_on "Create Prompt"

    assert_text "Prompt was successfully created"
    click_on "Back"
  end

  test "should update Prompt" do
    visit prompt_url(@prompt)
    click_on "Edit this prompt", match: :first

    fill_in "Background prompt", with: @prompt.background_prompt
    fill_in "Flow", with: @prompt.flow_id
    fill_in "Foreground prompt", with: @prompt.foreground_prompt
    check "Keep original background" if @prompt.keep_original_background
    fill_in "Light source direction", with: @prompt.light_source_direction
    fill_in "Light source strength", with: @prompt.light_source_strength
    fill_in "Negative prompt", with: @prompt.negative_prompt
    fill_in "Original background depth", with: @prompt.original_background_depth
    fill_in "Output format", with: @prompt.output_format
    fill_in "Preserve original subject", with: @prompt.preserve_original_subject
    fill_in "Seed", with: @prompt.seed
    click_on "Update Prompt"

    assert_text "Prompt was successfully updated"
    click_on "Back"
  end

  test "should destroy Prompt" do
    visit prompt_url(@prompt)
    click_on "Destroy this prompt", match: :first

    assert_text "Prompt was successfully destroyed"
  end
end
