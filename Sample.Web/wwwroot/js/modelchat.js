$(() => {
    const endpoint = '/api/modelchat';
    const responseDiv = $('#response');
    const submitButton = document.querySelector('#submit');
    const converter = new showdown.Converter();

    let history = [];

    submitButton.addEventListener('click', async () => {
        $('#submit').prop('disabled', true);

        const promptVal = $('#prompt').val();
        const fetchOptions = {
            method: 'POST',
            body: JSON.stringify({
                messages: history,
                prompt: promptVal
            }),
            headers: {
                'Content-Type': 'application/json'
            }
        };

        history.push({ isResponse: false, prompt: promptVal });
        responseDiv.append(`<div class="chat-message request-message">${promptVal}</div>`);
        $('#prompt').val('');

        // Append three dots spinner to indicate the model is working.  Set this ID as "active" so we can remove it later
        responseDiv.append(`
            <div id="active">
                <div class="dot-pulse text-center"></div>
            </div>`
        );

        try {
            console.log('Fetching... options:', fetchOptions);
            const response = await fetch(endpoint, fetchOptions);
            console.log(`Response: ${response.status} ${response.statusText}`);
            const json = await response.json();
            console.log(`JSON: ${JSON.stringify(json)}`);
            history.push({ isResponse: true, prompt: json.content });

            // Remove the spinner DIV.
            const element = document.getElementById('active');
            element.parentNode.removeChild(element);

            // Append the response to the chat window.
            responseDiv.append(`<div class="chat-message response-message">${converter.makeHtml(json.content)}</div>`);
        } catch (error) {
            // Remove the spinner DIV.
            const element = document.getElementById('active');
            element.parentNode.removeChild(element);

            responseDiv.append('<div class="alert alert-danger" role="alert">An error occurred. Please try again.</div>');
        }
        $('#submit').prop('disabled', false);
    });
});