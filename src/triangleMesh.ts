        export class TriangleMesh {

        buffer: GPUBuffer
        bufferLayout: GPUVertexBufferLayout


        constructor(device: GPUDevice){
        
        //array di 32bitfloat
        const vertices : Float32Array = new Float32Array([

                 0.0,  0.5, 1.0, 0.0, 0.0,
                -0.5, -0.5, 0.0, 1.0, 0.0,
                 0.5, -0.5, 0.0, 0.0, 1.0

        ])

            const usage : GPUBufferUsageFlags = GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST;
        
            const descriptor : GPUBufferDescriptor = {
        
                size: vertices.byteLength,
                usage: usage,
                mappedAtCreation: true
        
            };
        
            const buffer: GPUBuffer = device.createBuffer(descriptor);
            new Float32Array(buffer.getMappedRange()).set(vertices);
            buffer.unmap();
        
            const bufferLayout: GPUVertexBufferLayout = {
        
                arrayStride: 20,
                attributes: [
                    {
                        shaderLocation: 0,
                        offset: 0,
                        format: "float32x2"
                    },
                    {
                        shaderLocation: 1,
                        offset: 8,
                        format: "float32x3"
                    }
                ]
        
        
            };

        }

        }