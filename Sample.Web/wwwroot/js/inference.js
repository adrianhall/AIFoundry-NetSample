$(() => {
    const endpoint = '/api/inference';
    const responseDiv = $('#response');
    const submitButton = document.querySelector('#submit');
    const converter = new showdown.Converter();

    const spinnerHtml = `
        <div class="d-flex justify-content-center">
            <div class="spinner-border text-primary" role="status">
                &nbsp;
            </div>
        </div>
    `;

    submitButton.addEventListener('click', async () => {
        $('#submit').prop('disabled', true);
        responseDiv.html(spinnerHtml);

        const fetchOptions = {
            method: 'POST',
            body: JSON.stringify({ prompt: $('#prompt').val() }),
            headers: {
                'Content-Type': 'application/json'
            }
        };

        try {
            console.log('Fetching...');
            const response = await fetch(endpoint, fetchOptions);
            console.log(`Response: ${response.status} ${response.statusText}`);
            const json = await response.json();
            console.log(`JSON: ${JSON.stringify(json)}`);
            var html = converter.makeHtml(json.content);
            responseDiv.html(converter.makeHtml(json.content));
        } catch (error) {
            responseDiv.html('<div class="alert alert-danger" role="alert">An error occurred. Please try again.</div>');
        }
        $('#submit').prop('disabled', false);
    });
});