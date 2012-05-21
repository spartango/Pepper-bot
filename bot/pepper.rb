require 'logger'
require 'blather/stanza/message'
require 'posterous'
require 'amatch'

module Bot
    class Pepper 
        def initialize(username, password, apiKey)
            @username = username
            @password = password
            @apiKey = apiKey


            @log       = Logger.new(STDOUT)
            @log.level = Logger::DEBUG
        end

        # Messaging

        def buildMessage(user, body) 
            return Blather::Stanza::Message.new user, body
        end

        
        def popAndBuild(stopWord, stack)
            buffer = []
            while not stack.empty?
                word = stack.pop
                if word == stopWord
                    break
                end
                buffer.push word
            end
            return buffer.reverse.join(' ')
        end

        # Events
        def onStatus(fromNodeName)
            # Dont do anything on status
            return []
        end

        # Query
        def onQuery(message)
            # Pepper Queries
            senderName = message.from.node.to_s

            queryText = message.body # Strip the Pepper part out
            
            # 
                        
            # Get all workspaces
            if queryText.match /help/i
                sender = message.from.stripped
                return []

            elsif queryText.match /thank/i
                return [(buildMessage message.from.stripped, "Pepper: No problem, "+senderName)]
            
            elsif queryText.match /hi/i or queryText.match /hello/i or queryText.match /hey/i
                return [(buildMessage message.from.stripped, "Pepper: Hello, "+senderName)]
            end  
            # Default / Give up
            return [(buildMessage message.from.stripped, "Pepper: Sorry? Is there a way I can help?")]
        end

        def onMessage(message, &onProgress)
            # Query handling
            queryMsgs = []
            if message.body.match /Pepper/i 
                queryMsgs = onQuery message, &onProgress
            end

            return queryMsgs
        end

    end
end
