require "application_system_test_case"

class RunsTest < ApplicationSystemTestCase
  setup do
    @run = runs(:one)
  end

  test "visiting the index" do
    visit runs_url
    assert_selector "h1", text: "Runs"
  end

  test "should create run" do
    visit runs_url
    click_on "New run"

    fill_in "Completed at", with: @run.completed_at
    fill_in "Flow", with: @run.flow_id
    fill_in "Started at", with: @run.started_at
    fill_in "Status", with: @run.status
    click_on "Create Run"

    assert_text "Run was successfully created"
    click_on "Back"
  end

  test "should update Run" do
    visit run_url(@run)
    click_on "Edit this run", match: :first

    fill_in "Completed at", with: @run.completed_at.to_s
    fill_in "Flow", with: @run.flow_id
    fill_in "Started at", with: @run.started_at.to_s
    fill_in "Status", with: @run.status
    click_on "Update Run"

    assert_text "Run was successfully updated"
    click_on "Back"
  end

  test "should destroy Run" do
    visit run_url(@run)
    click_on "Destroy this run", match: :first

    assert_text "Run was successfully destroyed"
  end
end
