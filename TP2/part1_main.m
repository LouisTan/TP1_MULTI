% INF4710 A2017 TP2

close all;
clear;
clc;

% you have to test all configurations by modifying the parameters below!
USE_SUBSAMPLING = 0;
USE_QUANT_QUALITY = 100;

test_image_paths = { ...
    'data/tp2/colors.png',...       % 16x16
    'data/tp2/airplane.png', ...    % 512x512
    'data/tp2/baboon.png', ...      % 512x512
    'data/tp2/cameraman.tif', ...   % 256x256 
    'data/tp2/lena.png', ...        % 512x512
    'data/tp2/logo.tif', ...        % 256x256
    'data/tp2/logo_noise.tif', ...  % 256x256
    'data/tp2/peppers.png', ...     % 512x512
};

for t=1:numel(test_image_paths)
    input = imread(test_image_paths{t});
    assert(numel(input)>0);
    if(size(input,3)==1)
        input = cat(3,input,input,input);
    elseif(size(input,3)==4)
        input = input(:,:,1:3);
    end
    
%     figure;
%     imshow(input);
    
    % COMPRESSION ************************************
    [Y,Cb,Cr] = conv_rgb2ycbcr(input,USE_SUBSAMPLING); %512*512*3
    
%      figure;
%      imshow(cat(3,Y,Cb,Cr));
    
    % DECOUPAGE **************************************
    blocks_y = decoup(Y); %8*8*4096
    blocks_cb = decoup(Cb);
    blocks_cr = decoup(Cr);
    
    blocks = cat(3,blocks_y,blocks_cb,blocks_cr); %8*8*12288
    
%     % TRANSFORMEE COSINUS DISCRETE *******************
%     blocks_dct = zeros(size(blocks));
%     for b=1:size(blocks,3)
%         blocks_dct(:,:,b) = dct(blocks(:,:,b));
%     end
%     %disp(blocks_dct1); 8*8*12288

% TRANSFORMEE COSINUS DISCRETE *******************
    blocks_dct = zeros(size(blocks));
    for b=1:size(blocks,3)
        blocks_dct(:,:,b) = DCT1(blocks(:,:,b));
    end
    %disp(blocks_dct1); 8*8*12288
    
    % QUANTIFICATION *********************************
    blocks_quantif = zeros(size(blocks_dct),'int16');
    for b=1:size(blocks_dct,3)
        blocks_quantif(:,:,b) = quantif(blocks_dct(:,:,b),USE_QUANT_QUALITY);
    end
    %disp(blocks_quantif); 8*8*12288
    
    % ZIG ZAG ****************************************
    blocks_vectors = zeros(size(blocks_quantif,1)*size(blocks_quantif,2),size(blocks_quantif,3),'int16');
    for b=1:size(blocks_quantif,3)
        blocks_vectors(:,b) = zigzag(blocks_quantif(:,:,b));
    end
    %disp(blocks_vectors); 64*12288
    
    % CODAGE DE HUFFMAN ******************************
    code = encodeHuff(blocks_vectors); %64*12288

    % @@@@ TODO: check compression rate here...
    % compr_rate = 1.0 - (numel(code)./(numel(input))*8);
    % fprintf('\t... compression rate = %f\n',compr_rate);

    % DECODAGE DE HUFFMAN*****************************
    blocks_vectors_decompr = decodeHuff(code,8*8); %64*12288
    
    % ZIG ZAG INVERSE
    blocks_quantif_decompr = zeros([sqrt(size(blocks_vectors,1)),sqrt(size(blocks_vectors,1)),size(blocks_quantif,3)],'int16');
    for b=1:size(blocks_vectors_decompr,2)
        blocks_quantif_decompr(:,:,b) = zigzag_inv(blocks_vectors_decompr(:,b));
    end
    %disp(blocks_quantif_decompr); 8*8*12288
    
    % DEQUANTIFICATION *******************************
    blocks_dct_decompr = zeros(size(blocks_quantif_decompr));
    for b=1:size(blocks_quantif_decompr,3)
        blocks_dct_decompr(:,:,b) = quantif_inv(blocks_quantif_decompr(:,:,b),USE_QUANT_QUALITY);
    end
    %disp(blocks_quantif_decompr); 8*8*12288
    
%     TRANSFORMEE COSINUS DISCRETE INVERSE ***********
%     blocks_decompr = zeros(size(blocks_dct_decompr),'uint8');
%     for b=1:size(blocks_decompr,3)
%         blocks_decompr(:,:,b) = dct_inv(blocks_dct_decompr(:,:,b));
%     end
%     disp(blocks_decompr); 8*8*12288

    % TRANSFORMEE COSINUS DISCRETE INVERSE ***********
    blocks_decompr = zeros(size(blocks_dct_decompr),'uint8');
    for b=1:size(blocks_decompr,3)
        blocks_decompr(:,:,b) = IDCT(blocks_dct_decompr(:,:,b));
    end
    %disp(blocks_decompr); 8*8*12288
    
    % DECOUPAGE **************************************
    Y_decompr = decoup_inv(blocks_decompr(:,:,1:size(blocks_y,3)),size(Y)); %512*512
    Cb_decompr = decoup_inv(blocks_decompr(:,:,size(blocks_y,3)+1:size(blocks_y,3)+size(blocks_cb,3)),size(Cb));
    Cr_decompr = decoup_inv(blocks_decompr(:,:,size(blocks_y,3)+1+size(blocks_cb,3):end),size(Cr));
    
    % DECOMPRESSION **********************************
    input_decompr = conv_ycbcr2rgb(Y_decompr,Cb_decompr,Cr_decompr,USE_SUBSAMPLING); %512*512*3
    if ~isequal(size(input_decompr),size(input))
        error('\n ERROR! Reconstructed image had different size from original... aborting.\n\n');
    end
    
    figure;
    imshow(input_decompr);
    %imshow(cat(2,input,input_decompr,imabsdiff(input,input_decompr)));
    
    if(isequal(input,input_decompr))
        fprintf('\t... done. Compression is LOSSLESS.\n');
    else
        diff = double(input)-double(input_decompr);
        L2Dist = sqrt(sum(sum(sum(diff.*diff))));
        MSE = L2Dist*L2Dist/(numel(input));
        PSNR = 10*log10((255.*255.)/MSE);
        fprintf(['\t... done. Compression is LOSSY (PSNR=' num2str(PSNR) 'dB, and ' num2str(double(nnz(max(input~=input_decompr,[],3)))*100/(numel(input)/3)) '%% of pixels have altered values).\n']);
    end
    
end
fprintf('all done\n');
