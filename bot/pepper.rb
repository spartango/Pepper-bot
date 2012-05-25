require 'logger'
require 'blather/stanza/message'
require 'gmail'
require 'amatch'

module Bot
    class Pepper 
        def initialize(username, password, posterousAddress)
            @gmail = Gmail.connect(username, password)
            @posterousAddress = posterousAddress

            @recordings = {} # Keeps track of conversations being recorded

            @log       = Logger.new(STDOUT)
            @log.level = Logger::DEBUG
        end

        # Messaging
        def buildMessage(user, body) 
            return Blather::Stanza::Message.new user, body
        end

        # Posterous interface
        def postToPosterous(postTitle, postBody)
            @log.debug "[Pepper]: Building message for post: "+postTitle
            posterousAddress = @posterousAddress
            message = @gmail.compose do
                to posterousAddress
                subject postTitle
                body postBody
            end
            message.deliver!
            @log.debug "[Pepper]: Sent message!"
        end

        # Handlers
        def handleNewPost(requester, postTitle, postBody)
            postToPosterous(postTitle, postBody)
            return [(buildMessage requester, "I've put the post up on Posterous")]
        end

        def handleRecordingFinished(requester)
            key = requester.to_s
            if not @recordings.has_key key
                return [(buildMessage requester, "I wasn't recording this conversation, sorry!")]
            end

            @log.debug "[Pepper]: Finishing recording messages from "+requester.node.to_s

            # Pull all the messages down
            messages = @recordings[key]

            # Stop the recording
            @recordings.delete key

            # Coalesce them 
            postBody = messages.join('\n')
            postTitle = "Conversation "+Time.now.strftime("%-m/%-d/%Y at %H:%M")

            # Make a new post
            return handleNewPost requester, postTitle, postBody
        end

        def handleRecordingStop(requester)
            key = requester.to_s
            if @recordings.has_key? key
                @recordings.delete key

                @log.debug "[Pepper]: Stopped recording messages from "+requester.node.to_s
                return [(buildMessage requester, "I've stopped recording the conversation. I won't post it.")]
            end

            return [(buildMessage requester, "I wasn't recording this conversation anyway")]

        end

        def handleNewRecording(requester)
            # Add a key in the recordings for the requester
            key = requester.to_s
            if @recordings.has_key? key
                return [(buildMessage requester, "I'm already recording this conversation")]
            end

            @log.debug "[Pepper]: Started recording messages from "+requester.node.to_s
            @recordings[key] = []
            return [(buildMessage requester, "I've started recording the conversation")]
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
            return buffer.join(' ')
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
            senderId = message.from.stripped
            queryText = message.body
            
            # Create a new post all at once
            if queryText.match /new post/i
                # ... new post titled [title] saying [body]
                postParams = parsePost queryText

                yield (buildMessage message.from.stripped, "Getting your post ready...")

                return handleNewPost message.from.stripped, postParams[:title], postParams[:body] if postParams

                return [(buildMessage message.from.stripped, "Sorry, I couldn't post that.")] # onError

            elsif queryText.match /finish/i
                yield (buildMessage message.from.stripped, "Finished recording, getting your post ready...")

                return handleRecordingFinished senderId

            elsif queryText.match /stop/i
                return handleRecordingStop senderId

            elsif queryText.match /record/i
                return handleNewRecording senderId

            elsif queryText.match /help/i
                return [(buildMessage senderId, "I'm not ready to help you...")] # onError

            elsif queryText.match /thank/i
                return [(buildMessage senderId, "No problem!")]
            
            elsif queryText.match /hi/i or queryText.match /hello/i or queryText.match /hey/i
                return [(buildMessage senderId, "Hello.")]
            end  
            # Default / Give up
            return [(buildMessage senderId, "Sorry? Is there a way I can help?")]
        end

        def onMessage(message, &onProgress)
            # Query handling
            queryMsgs = []
            if message.body.match /Pepper/i 
                queryMsgs = onQuery message, &onProgress
            end

            key = message.from.stripped.to_s
            if @recordings.has_key? key
                # Save the message
                recordings[key].push message.body
            end

            return queryMsgs
        end

    end
end
