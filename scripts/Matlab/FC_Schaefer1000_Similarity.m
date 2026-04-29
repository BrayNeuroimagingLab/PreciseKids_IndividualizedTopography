
%% --- Visualize ---

is_child = group_labels == 'Child';
is_adult = group_labels == 'Adult';


if sum(is_child) ~= 24 || sum(is_adult) ~= 24
    warning('Expected 24 Children and 24 Adults, but found different counts.');
end


sim_child = similarity_matrix(is_child, is_child);  % 24x24
sim_adult = similarity_matrix(is_adult, is_adult);  % 24x24

% Calculate group means
mean_child = mean(sim_child(triu(true(24), 1)), 'omitnan');
mean_adult = mean(sim_adult(triu(true(24), 1)), 'omitnan');

fprintf('Mean within-child similarity: %.4f\n', mean_child);
fprintf('Mean within-adult similarity: %.4f\n', mean_adult);


vmin = min([sim_child(:); sim_adult(:)], [], 'omitnan');
vmax = max([sim_child(:); sim_adult(:)], [], 'omitnan');

% Plot
figure('Name', 'Child–Child FC Similarity', 'Position', [100 100 500 400]);
imagesc(sim_child);
title(sprintf('Child–Child FC Similarity (Mean = %.3f)', mean_child));
colorbar;
caxis([vmin vmax]);
axis square;
xticks(1:24); yticks(1:24); xlabel('Child'); ylabel('Child');

% Plot
figure('Name', 'Adult–Adult FC Similarity', 'Position', [700 100 500 400]);
imagesc(sim_adult);
title(sprintf('Adult–Adult FC Similarity (Mean = %.3f)', mean_adult));
colorbar;
caxis([vmin vmax]);
axis square;
xticks(1:24); yticks(1:24); xlabel('Adult'); ylabel('Adult');

% Save
exportgraphics(gcf, fullfile(fc_dir, 'Adult_Adult_Similarity.png'), 'Resolution', 300);
figure(1);  % child
exportgraphics(gcf, fullfile(fc_dir, 'Child_Child_Similarity.png'), 'Resolution', 300);


%% With higher motion adult and 4 higher motion children excluded:

% Indices to exclude
exclude_adult_idx = 15;             % Adult #15 (017P)
exclude_child_idx = [6, 10, 14, 20]; % Children #6, 10, 14, 20

% Logical masks
is_child = group_labels == 'Child';
is_adult = group_labels == 'Adult';

% Get indices of all children and adults
child_idx = find(is_child);  % Should be 1:24
adult_idx = find(is_adult);  % Should be 1:24

% Remove excluded indices
child_idx(exclude_child_idx) = [];
adult_idx(exclude_adult_idx) = [];

% Extract cleaned similarity submatrices
sim_child = similarity_matrix(child_idx, child_idx);  % 20x20
sim_adult = similarity_matrix(adult_idx, adult_idx);  % 23x23

% Compute means
mean_child = mean(sim_child(triu(true(20), 1)), 'omitnan');
mean_adult = mean(sim_adult(triu(true(23), 1)), 'omitnan');

fprintf('Mean within-child similarity (20 included): %.4f\n', mean_child);
fprintf('Mean within-adult similarity (23 included): %.4f\n', mean_adult);

% Normalize color scale
vmin = min([sim_child(:); sim_adult(:)], [], 'omitnan');
vmax = max([sim_child(:); sim_adult(:)], [], 'omitnan');

% Plot Child
figure('Name', 'Child–Child FC Similarity', 'Position', [100 100 500 400]);
imagesc(sim_child);
title(sprintf('Child–Child FC Similarity (Mean = %.3f)', mean_child));
colorbar; caxis([vmin vmax]); axis square;
xticks(1:20); yticks(1:20); xlabel('Child'); ylabel('Child');

% Plot Adult
figure('Name', 'Adult–Adult FC Similarity', 'Position', [700 100 500 400]);
imagesc(sim_adult);
title(sprintf('Adult–Adult FC Similarity (Mean = %.3f)', mean_adult));
colorbar; caxis([vmin vmax]); axis square;
xticks(1:23); yticks(1:23); xlabel('Adult'); ylabel('Adult');


