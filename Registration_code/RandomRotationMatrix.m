
function [Q] = RandomRotationMatrix(seed)

Q = orth(randn(3));
% select random locations on the sphere
% rng(seed);
% goodangles = 1800;
% while abs(goodangles) > 1500
%     % randomly rotate points
%     A = zeros(3,3);
%     for i=1:3
%         for j=1:3
%             A(i,j) = randn();
%         end
%     end
%     for jInterate = 1:6
%         At = transpose(A);
%         Ainv = inv(At);
%         A = (A + Ainv)/2;
%         % how orthogonal?
%         test_ortho = A*transpose(A);
%     end
%     if det(A) > 0
%         Q = A;
%         eul = rotm2eul(Q);
%         goodangles = sum(abs(eul)*180/pi);
%     else
%         goodangles = 1800;
%     end
% end
%  
