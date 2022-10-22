# frozen_string_literal: true

require_relative '../../app/sqlui'
require_relative '../spec_helper'

describe SQLUI do
  let(:sqlui) do
    SQLUI.new(client: nil, name: 'test', saved_path: 'path')
  end

  it 'can be loaded' do
    sqlui
  end
end
