# frozen_string_literal: true

require 'base64'

require_relative '../spec_helper'
require_relative 'spec_helper'

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

    driver.get(url('/sqlui/friends/saved'))
  end

  let(:expected_file_names) do
    %w[nicholasdower/sqlui/master/sql/friends/sample_one.sql nicholasdower/sqlui/master/sql/friends/sample_two.sql]
  end

  it 'displays the list of saved queries' do
    name_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > h2')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    names = name_elements.map(&:text)
    expect(names).to eq(expected_file_names)
  end

  it 'view links to the query' do
    view_link_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .links > .view-link')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    view_link_elements.first.click
    wait_until_no_results(wait)
  end

  it 'run links to the query and results' do
    run_link_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .links > .run-link')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    run_link_elements.first.click
    wait_until_results(wait, %w[id name description actor_id], ['1', "GW\nMonica", 'A neat freak.', '1'])
  end
end
