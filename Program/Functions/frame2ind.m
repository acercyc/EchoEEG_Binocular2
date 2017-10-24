% 1.0 - Acer 2017/10/24 16:13
function ind = frame2ind(iFrame, nFrame, category)
ind = sum(iFrame > quantile(1:nFrame, category));