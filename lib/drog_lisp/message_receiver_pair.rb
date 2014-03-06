
# This class encapsulates the idea of a message being sent to an underlying Ruby object.

# A receiver can be
# an object
# a symbol, which should be resolved to an object using Kernel#const_get

# The message is either
# an array
#  in which case it is splatted in
# or anything else
#  which is sent directly

class MessageReceiverPair
  
  def initialize message, receiver
    @receiver = resolve_receiver receiver
    @performer  = create_performer message
  end

  def perform
    @performer.call @receiver
  end

  private

  def resolve_receiver receiver
    if receiver.kind_of? Symbol
      return Kernel.const_get receiver
    end
    receiver
  end

  def create_performer message
    if not message.kind_of? Array
      ->(receiver) { receiver.send message }
    else
      ->(receiver) { receiver.send message.first, *message.drop(1) }
    end
  end
end

