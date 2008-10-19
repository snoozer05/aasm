describe Conversation, 'description' do
  it '.states should contain all of the states' do
    Conversation.states.should == [:needs_attention, :read, :closed, :awaiting_response, :junk]
  end
end
