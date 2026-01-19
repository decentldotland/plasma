global type Payload = {string: any}
global type ReplyFn = function(Payload): nil
global Send: function(Payload): nil

global record Tag
    name: string | nil
    Name: string | nil
    value: string | nil
    Value: string | nil
end

global record Msg
    From: string
    Id: string | nil
    Tags: {Tag} | {string: string} | nil
    TagArray: {Tag} | nil
    reply: ReplyFn | nil
end