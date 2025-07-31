exports.handler = async (event) => {
    const httpMethod = event.httpMethod || event.requestContext?.http?.method;
    const path = event.path || event.requestContext?.http?.path || '/';
    
    // Set CORS headers for CloudFront integration
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    };

    try {
        // Handle OPTIONS preflight requests
        if (httpMethod === 'OPTIONS') {
            return {
                statusCode: 200,
                headers,
                body: ''
            };
        }

        // Handler 1: Health Check (root path)
        if (path === '/' || path === '') {
            const response = {
                message: 'Real API is running successfully',
                apiName: 'real-api',
                timestamp: new Date().toISOString(),
                status: 'healthy'
            };

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(response)
            };
        }

        // Handler 2: Echo Test
        if (path === '/echo') {
            if (httpMethod !== 'POST') {
                return {
                    statusCode: 405,
                    headers,
                    body: JSON.stringify({
                        error: 'Method not allowed',
                        message: 'Echo endpoint only accepts POST requests'
                    })
                };
            }

            let requestBody = {};
            if (event.body) {
                try {
                    requestBody = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
                } catch (parseError) {
                    return {
                        statusCode: 400,
                        headers,
                        body: JSON.stringify({
                            error: 'Invalid JSON',
                            message: 'Request body must be valid JSON'
                        })
                    };
                }
            }

            const response = {
                message: 'This is the message I received',
                originalMessage: requestBody,
                apiName: 'real-api',
                timestamp: new Date().toISOString()
            };

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(response)
            };
        }

        // Handle unknown paths
        return {
            statusCode: 404,
            headers,
            body: JSON.stringify({
                error: 'Not Found',
                message: 'The requested path was not found',
                availablePaths: ['/', '/echo']
            })
        };

    } catch (error) {
        console.error('Error processing request:', error);
        
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Internal Server Error',
                message: 'An unexpected error occurred'
            })
        };
    }
};