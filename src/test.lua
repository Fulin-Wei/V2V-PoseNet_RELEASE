require 'torch'
require 'optim'
require 'image'
require 'os'
require 'sys'

function test(testRefPt, testName)
    
    model:evaluate()
    testDataSz = #testName
    print('==> testing:')
    
    inputs = torch.Tensor(batchSz,inputDim,croppedSz,croppedSz,croppedSz):fill(bkgValue)
    inputs_cuda = torch.CudaTensor(batchSz,inputDim,croppedSz,croppedSz,croppedSz):fill(bkgValue)
    refPts = torch.Tensor(batchSz,worldDim):zero()
    xyzOutput = torch.CudaLongTensor(batchSz,jointNum,worldDim):zero()

    for t = 1,testDataSz,batchSz do
        
        curBatchNum = batchSz
        inputs:fill(bkgValue)
        
        --generate batch
        for i = t,t+curBatchNum-1 do
            
            local input_name = testName[i]
            local refPt = testRefPt[i]:clone()
            local depthimage = load_depthmap(input_name)

            refPts[i-t+1] = refPt
            
            --canceling data augmentation (it was prepared before)
            newSz = 100
            angle = 0
            local trans = torch.Tensor(worldDim)
            trans[1] = originalSz/2 - croppedSz/2 + 1
            trans[2] = originalSz/2 - croppedSz/2 + 1
            trans[3] = originalSz/2 - croppedSz/2 + 1
            
            --voxelizing
            inputs[i-t+1] = generate_cubic_input(inputs[i-t+1][1],depthimage,refPts[i-t+1],newSz,angle,trans)
            
        end
        inputs_cuda[{{}}] = inputs[{{}}]

        --forward the input to output
        outputs = model:forward(inputs_cuda)
        
        --warp to real-world coordinate
        xyzOutput = extract_coord_from_output(outputs,xyzOutput):type('torch.CudaTensor')
        xyzOutput = xyzOutput * poolFactor
        for bid = 1,curBatchNum do
            xyzOutput[bid] = warp2continuous(xyzOutput[bid],refPts[bid])           
        end

        --xyzOutput is 3D joint coordinates (final output) in world coordinate system
        --you need to convert them into pixel coordinate system if needed
        --write save code here
        
        
        
        --type convert to the original type
        xyzOutput = xyzOutput:type('torch.CudaLongTensor')
        
    end
    

end
