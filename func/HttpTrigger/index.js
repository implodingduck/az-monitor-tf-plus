module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');

    const name = (req.query.name || (req.body && req.body.name));
    const responseMessage = name
        ? "Hello, " + name + ". This HTTP triggered function executed successfully."
        : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";
    if ( name && name.toLowerCase().indexOf('fail') > 0){
        throw new Error('This is an error because the name contains fail...')
    }
    context.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
}