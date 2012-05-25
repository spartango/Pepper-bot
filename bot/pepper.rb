require 'logger'
require 'blather/stanza/message'
require 'gmail'
require 'amatch'

module Bot
    class Pepper 
        def initialize(username, password, posterousAddress)
            @gmail = Gmail.connect(username, password)
            @posterousAddress = posterousAddress

            @log       = Logger.new(STDOUT)
            @log.level = Logger::DEBUG
        end

        # Messaging
        def buildMessage(user, body) 
            return Blather::Stanza::Message.new user, body
        end

        # Posterous interface
        def postToPosterous(postTitle, postBody)
            @gmail.deliver do
                to @posterousAddress
                subject postTitle
                body postBody
            end
        end

        # Handlers
        def handleNewPost(requester, postTitle, postBody)
            postToPosterous(postTitle, postBody)
            return [(buildMessage requester, "I've put the post up on Posterous")]
        end

        # Parsing Utils
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

        # Parsers
        def parsePost(queryText)
            # Build stack
            parts = queryText.split(' ')

            # Consume until 'post'
            stack = []

            pushing = false
            parts.each do |word|
                if pushing
                    # Push all
                    stack.push word
                elsif word == 'titled'
                    pushing = true
                end
            end
            # We want to handle the parts from the front
            stack.reverse!

            # Pull off the front for the title until saying
            title = popAndBuild 'saying', stack

            # Rest is body
            body = popAndBuild '', stack

            return nil if title == '' or body == ''

            return {:title => title, :body => body}
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

            queryText = message.body
            
            # Create a new post all at once
            if queryText.match /new post/i
                # ... new post titled [title] saying [body]
                postParams = parsePost queryText

                yield (buildMessage message.from.stripped, "Getting your post ready...")

                return handleNewPost message.from.stripped, postParams[:title], postParams[:body] if postParams

                return [(buildMessage message.from.stripped, "Sorry, I couldn't post that.")] # onError
 
            elsif queryText.match /help/i
                sender = message.from.stripped
                return [(buildMessage message.from.stripped, "I'm not ready to help you...")] # onError

            elsif queryText.match /thank/i
                return [(buildMessage message.from.stripped, "No problem!")]
            
            elsif queryText.match /hi/i or queryText.match /hello/i or queryText.match /hey/i
                return [(buildMessage message.from.stripped, "Hello.")]
            end  
            # Default / Give up
            return [(buildMessage message.from.stripped, "Sorry? Is there a way I can help?")]
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
