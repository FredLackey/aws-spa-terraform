// ${project_prefix}-${environment} API - Placeholder Implementation
// Health check and echo endpoints for testing

exports.handler = async (event) => {
    // Extract request information
    const { requestContext, rawPath, rawQueryString, headers, body } = event;
    const httpMethod = requestContext?.http?.method || 'GET';
    const path = rawPath || '/';
    const queryString = rawQueryString || '';
    
    console.log('Request received:', {
        method: httpMethod,
        path: path,
        queryString: queryString,
        headers: headers
    });
    
    try {
        // Route requests
        if (path === '/' || path === '/health') {
            return handleHealthCheck();
        } else if (path === '/echo') {
            return handleEcho(event);
        } else {
            return handleNotFound(path);
        }
    } catch (error) {
        console.error('Error processing request:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message,
                timestamp: new Date().toISOString()
            })
        };
    }
};

function handleHealthCheck() {
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        body: JSON.stringify({
            status: 'healthy',
            service: '${project_prefix}-${environment}-api',
            timestamp: new Date().toISOString(),
            version: '1.0.0',
            environment: '${environment}'
        })
    };
}

function handleEcho(event) {
    const { requestContext, rawPath, rawQueryString, headers, body } = event;
    
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        body: JSON.stringify({
            message: 'Echo response',
            request: {
                method: requestContext?.http?.method || 'GET',
                path: rawPath || '/',
                queryString: rawQueryString || '',
                headers: headers || {},
                body: body ? JSON.parse(body) : null
            },
            server: {
                service: '${project_prefix}-${environment}-api',
                timestamp: new Date().toISOString(),
                environment: '${environment}'
            }
        })
    };
}

function handleNotFound(path) {
    return {
        statusCode: 404,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        body: JSON.stringify({
            error: 'Not found',
            message: `Path '${path}' not found`,
            timestamp: new Date().toISOString(),
            service: '${project_prefix}-${environment}-api'
        })
    };
}