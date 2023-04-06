# frozen_string_literal: true

require_relative '../spec/spec_helper'
require_relative '../spec/browser/spec_helper'

describe 'saved' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  let(:tree_response) do
    {
      sha: 'some_sha',
      truncated: false,
      tree: [
        { path: 'sql/friends/sample_one.sql' },
        { path: 'sql/friends/sample_two.sql' }
      ]
    }
  end

  let(:content_response) { { content: Base64.encode64('select * from characters limit 1;') } }

  before do
    stub_request(:get, 'https://api.github.com/repos/nicholasdower/sqlui/git/trees/master?recursive=true')
      .to_return(body: tree_response.to_json, status: 200)
    stub_request(:get, 'https://api.github.com/repos/nicholasdower/sqlui/contents/sql/friends/sample_one.sql?ref=some_sha')
      .to_return(body: content_response.to_json, status: 200)
    stub_request(:get, 'https://api.github.com/repos/nicholasdower/sqlui/contents/sql/friends/sample_two.sql?ref=some_sha')
      .to_return(body: content_response.to_json, status: 200)
  end

  it 'is screenshotted' do
    driver.get(url('/sqlui/friends/saved'))
    driver.manage.window.resize_to(1200, 900)
    wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .saved-file-header > .saved-name')
      elements if elements.size == 2 && elements[0].displayed?
    end
    driver.save_screenshot('screenshots/saved.png')
  end
end
