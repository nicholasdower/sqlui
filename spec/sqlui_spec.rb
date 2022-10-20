require_relative '../app/sqlui'

describe SQLUI do
  let(:sqlui) do
    SQLUI.new(client: nil, name: 'test', saved_path: 'path')
  end

  it 'can be loaded' do
    sqlui
  end
end
