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

        try {
            console.log('Fetching...');
            const response = await fetch(endpoint, fetchOptions);
            console.log(`Response: ${response.status} ${response.statusText}`);
            const json = await response.json();
            console.log(`JSON: ${JSON.stringify(json)}`);
            history.push({ isResponse: true, response: json.content });
            responseDiv.append(`<div class="chat-message response-message">${converter.makeHtml(json.content)}</div>`);
        } catch (error) {
            responseDiv.append('<div class="alert alert-danger" role="alert">An error occurred. Please try again.</div>');
        }
        $('#submit').prop('disabled', false);
    });
});