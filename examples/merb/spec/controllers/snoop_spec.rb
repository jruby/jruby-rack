require File.join(File.dirname(__FILE__), "..", 'spec_helper.rb')

describe Snoop, "index action" do
  before(:each) do
    dispatch_to(Snoop, :index)
  end
end