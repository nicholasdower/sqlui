require 'sqlui'

describe SQLUI do
  let(:sqlui) do
    SQLUI.new(name: 'test', saved_path: 'path') do |sql|
      'result'
    end
  end

  it 'can be loaded' do
    sqlui
  end
end
